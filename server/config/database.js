/**
 * ============================================
 * DATABASE CONFIGURATION
 * ============================================
 * This file creates a connection pool to MySQL database.
 * 
 * WHAT IS A CONNECTION POOL?
 * --------------------------
 * Instead of creating a new connection every time we need
 * to talk to the database (slow), we create a "pool" of
 * connections that stay open and get reused (fast).
 * 
 * Think of it like a taxi stand - instead of calling a new
 * taxi every time, there are taxis waiting at the stand.
 * ============================================
 */

// Import mysql2 library with Promise support
// Promises let us use async/await (cleaner code)
const mysql = require('mysql2/promise');

// Load environment variables from .env file
require('dotenv').config();

/**
 * Create a connection pool
 * 
 * Pool settings explained:
 * - host: Where the database server is (localhost = your computer)
 * - port: The "door number" MySQL listens on (default 3306)
 * - user: MySQL username
 * - password: MySQL password
 * - database: Which database to use
 * - waitForConnections: If all connections are busy, wait for one
 * - connectionLimit: Maximum number of connections in the pool
 * - queueLimit: How many requests can wait (0 = unlimited)
 */
const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'RTC_Video_Chat_DB',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

/**
 * Test the database connection
 * 
 * This function tries to connect to the database and
 * returns true if successful, false if not.
 * 
 * We use this when the server starts to make sure
 * the database is accessible.
 */
async function testConnection() {
    try {
        // Get a connection from the pool
        const connection = await pool.getConnection();
        
        // Log success message
        console.log('✅ Database connected successfully!');
        console.log(`   Host: ${process.env.DB_HOST || 'localhost'}`);
        console.log(`   Database: ${process.env.DB_NAME || 'RTC_Video_Chat_DB'}`);
        
        // Release the connection back to the pool
        // (Very important! Otherwise connections run out)
        connection.release();
        
        return true;
    } catch (error) {
        // Log error message
        console.error('❌ Database connection failed!');
        console.error(`   Error: ${error.message}`);
        
        // Helpful tips based on common errors
        if (error.code === 'ECONNREFUSED') {
            console.error('   Tip: Is MySQL running? Try: brew services start mysql');
        } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
            console.error('   Tip: Check your DB_USER and DB_PASSWORD in .env file');
        } else if (error.code === 'ER_BAD_DB_ERROR') {
            console.error('   Tip: Database does not exist. We will create it on Day 2.');
        }
        
        return false;
    }
}

/**
 * Execute a raw SQL query
 * 
 * This is a helper function to run any SQL query.
 * Used mainly for creating database/tables initially.
 * 
 * For regular operations, we use stored procedures (Day 2+)
 */
async function query(sql, params = []) {
    try {
        const [results] = await pool.execute(sql, params);
        return { success: true, data: results };
    } catch (error) {
        console.error('Query error:', error.message);
        return { success: false, error: error.message };
    }
}

// Export the pool and functions so other files can use them
module.exports = { 
    pool,           // The connection pool
    testConnection, // Function to test connection
    query           // Function to run queries
};

