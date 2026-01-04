"""
============================================
DATABASE CONFIGURATION
============================================
Creates a connection pool to MySQL database.

WHAT IS A CONNECTION POOL?
Instead of creating a new database connection for each request (slow),
we create a "pool" of connections that stay open and get reused (fast).

Think of it like a taxi stand - instead of calling a new
taxi every time, there are taxis waiting at the stand.

ALL DATABASE ACCESS MUST USE STORED PROCEDURES!
No inline SQL queries allowed in the application.
============================================
"""

import pymysql
from pymysql.cursors import DictCursor
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


class Database:
    """
    Database connection manager.
    
    This class manages MySQL connections and provides
    helper methods to call stored procedures.
    """
    
    def __init__(self):
        """Initialize database configuration from environment variables."""
        self.config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': int(os.getenv('DB_PORT', 3306)),
            'user': os.getenv('DB_USER', 'root'),
            'password': os.getenv('DB_PASSWORD', ''),
            'database': os.getenv('DB_NAME', 'RTC_Video_Chat_DB'),
            'charset': 'utf8mb4',
            'cursorclass': DictCursor,  # Return results as dictionaries
            'autocommit': True
        }
    
    def get_connection(self):
        """
        Get a database connection.
        
        Returns:
            pymysql.Connection: Database connection object
        
        IMPORTANT: Always close the connection when done!
        Use 'with' statement for automatic cleanup.
        """
        return pymysql.connect(**self.config)
    
    def test_connection(self):
        """
        Test if database connection works.
        
        Returns:
            bool: True if connected successfully, False otherwise
        """
        try:
            conn = self.get_connection()
            print('✅ Database connected successfully!')
            print(f"   Host: {self.config['host']}")
            print(f"   Database: {self.config['database']}")
            conn.close()
            return True
        except Exception as e:
            print('❌ Database connection failed!')
            print(f"   Error: {str(e)}")
            
            # Helpful tips based on common errors
            if 'Access denied' in str(e):
                print('   Tip: Check your DB_USER and DB_PASSWORD in .env file')
            elif 'Unknown database' in str(e):
                print('   Tip: Database does not exist. Run schema.sql to create it.')
            elif "Can't connect" in str(e):
                print('   Tip: Is MySQL running? Try: brew services start mysql')
            
            return False
    
    def call_procedure(self, procedure_name, in_params=None, out_params=None):
        """
        Call a stored procedure with OUT parameters.
        
        Parameters:
            procedure_name (str): Name of stored procedure (e.g., 'dt_vc_create_user')
            in_params (list): List of input parameter values
            out_params (list): List of output parameter names
        
        Returns:
            dict: {'success': bool, 'data': dict, 'error': str}
        
        Example:
            result = db.call_procedure(
                'dt_vc_create_user',
                ['john', 'john@email.com', 'hashedpwd', 'John', None],
                ['p_user_id', 'p_success', 'p_message']
            )
        """
        in_params = in_params or []
        out_params = out_params or []
        
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            
            # Build parameter placeholders
            all_params = []
            param_placeholders = []
            
            # Add input parameters
            for param in in_params:
                param_placeholders.append('%s')
                all_params.append(param)
            
            # Add output parameter variables
            for out_name in out_params:
                param_placeholders.append(f'@{out_name}')
            
            # Build and execute CALL statement
            call_sql = f"CALL {procedure_name}({', '.join(param_placeholders)})"
            cursor.execute(call_sql, all_params)
            
            # Fetch output parameters if any
            out_results = {}
            if out_params:
                select_sql = f"SELECT {', '.join([f'@{name} AS {name}' for name in out_params])}"
                cursor.execute(select_sql)
                row = cursor.fetchone()
                out_results = row if row else {}
            
            return {'success': True, 'data': out_results, 'error': None}
            
        except Exception as e:
            print(f"❌ Error calling {procedure_name}: {str(e)}")
            return {'success': False, 'data': {}, 'error': str(e)}
            
        finally:
            if conn:
                conn.close()
    
    def call_procedure_with_results(self, procedure_name, params=None):
        """
        Call a stored procedure that returns a result set (SELECT).
        
        Parameters:
            procedure_name (str): Name of stored procedure
            params (list): List of parameter values
        
        Returns:
            dict: {'success': bool, 'data': list, 'error': str}
        
        Example:
            result = db.call_procedure_with_results(
                'dt_vc_get_user_by_email', 
                ['john@email.com']
            )
        """
        params = params or []
        
        conn = None
        try:
            conn = self.get_connection()
            cursor = conn.cursor()
            
            # Build parameter placeholders
            placeholders = ', '.join(['%s'] * len(params))
            call_sql = f"CALL {procedure_name}({placeholders})" if params else f"CALL {procedure_name}()"
            
            cursor.execute(call_sql, params)
            results = cursor.fetchall()
            
            return {'success': True, 'data': results, 'error': None}
            
        except Exception as e:
            print(f"❌ Error calling {procedure_name}: {str(e)}")
            return {'success': False, 'data': [], 'error': str(e)}
            
        finally:
            if conn:
                conn.close()
    
    def call_procedure_single_result(self, procedure_name, params=None):
        """
        Call a stored procedure that returns a single row.
        
        Returns:
            dict or None: Single row as dictionary, or None if no results
        """
        result = self.call_procedure_with_results(procedure_name, params)
        
        if result['success'] and len(result['data']) > 0:
            return result['data'][0]
        
        return None


# Create a global database instance
db = Database()

