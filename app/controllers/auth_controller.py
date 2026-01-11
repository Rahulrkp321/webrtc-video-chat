"""
============================================
AUTHENTICATION CONTROLLER
============================================
Handles user registration, login, and logout logic.

CONTROLLER PATTERN:
-------------------
Controllers separate business logic from routes.
Routes handle HTTP (requests/responses).
Controllers handle the actual work.

This makes code:
- Easier to test
- Easier to reuse
- More organized

FLOW:
    Route receives request
         ↓
    Route calls controller method
         ↓
    Controller does the work:
        - Validates input
        - Calls database
        - Formats response
         ↓
    Controller returns result
         ↓
    Route sends response
============================================
"""

import re
from datetime import datetime, timedelta, timezone
from flask import request
from app.config.database import db
from app.utils.password import hash_password, verify_password
from app.utils.jwt_helper import generate_token


class AuthController:
    """
    Handles all authentication operations.
    
    Methods:
        - register(): Create new user account
        - login(): Authenticate user and create session
        - logout(): Invalidate user session
        - get_me(): Get current user profile
    """
    
    # ============================================
    # VALIDATION RULES
    # ============================================
    
    # Minimum password length
    MIN_PASSWORD_LENGTH = 6
    
    # Email regex pattern
    EMAIL_PATTERN = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    
    # Username rules: 3-50 chars, alphanumeric and underscore
    USERNAME_PATTERN = r'^[a-zA-Z0-9_]{3,50}$'
    
    
    @staticmethod
    def validate_email(email: str) -> tuple:
        """
        Validate email format.
        
        Returns:
            tuple: (is_valid: bool, error_message: str or None)
        """
        if not email:
            return False, 'Email is required'
            
        if not re.match(AuthController.EMAIL_PATTERN, email):
            return False, 'Invalid email format'
            
        return True, None
    
    
    @staticmethod
    def validate_username(username: str) -> tuple:
        """
        Validate username format.
        
        Rules:
        - 3-50 characters
        - Only letters, numbers, and underscore
        """
        if not username:
            return False, 'Username is required'
            
        if len(username) < 3:
            return False, 'Username must be at least 3 characters'
            
        if len(username) > 50:
            return False, 'Username must be less than 50 characters'
            
        if not re.match(AuthController.USERNAME_PATTERN, username):
            return False, 'Username can only contain letters, numbers, and underscore'
            
        return True, None
    
    
    @staticmethod
    def validate_password(password: str) -> tuple:
        """
        Validate password strength.
        
        Rules:
        - At least 6 characters
        """
        if not password:
            return False, 'Password is required'
            
        if len(password) < AuthController.MIN_PASSWORD_LENGTH:
            return False, f'Password must be at least {AuthController.MIN_PASSWORD_LENGTH} characters'
            
        return True, None
    
    
    # ============================================
    # REGISTER
    # ============================================
    
    @staticmethod
    def register(data: dict) -> dict:
        """
        Register a new user.
        
        Parameters:
            data (dict): {
                'username': 'john',
                'email': 'john@example.com',
                'password': 'mypassword',
                'display_name': 'John Doe'  # optional
            }
            
        Returns:
            dict: {
                'success': True/False,
                'message': 'Success message or error',
                'data': {...} or None
            }
            
        PROCESS:
        1. Validate input data
        2. Hash the password
        3. Call stored procedure to create user
        4. Generate JWT token
        5. Create session in database
        6. Return user data and token
        """
        
        # ============================================
        # STEP 1: Extract and validate input
        # ============================================
        
        username = data.get('username', '').strip().lower()
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        display_name = data.get('display_name', '').strip()
        
        # Validate username
        is_valid, error = AuthController.validate_username(username)
        if not is_valid:
            return {'success': False, 'message': error, 'data': None}
        
        # Validate email
        is_valid, error = AuthController.validate_email(email)
        if not is_valid:
            return {'success': False, 'message': error, 'data': None}
        
        # Validate password
        is_valid, error = AuthController.validate_password(password)
        if not is_valid:
            return {'success': False, 'message': error, 'data': None}
        
        # Use username as display_name if not provided
        if not display_name:
            display_name = username
        
        # ============================================
        # STEP 2: Hash the password
        # ============================================
        
        password_hash = hash_password(password)
        
        # ============================================
        # STEP 3: Create user in database
        # ============================================
        
        result = db.call_procedure(
            'dt_vc_create_user',
            [username, email, password_hash, display_name, 0],  # 0 = self registration
            ['p_user_id', 'p_success', 'p_message']
        )
        
        if not result['success']:
            return {
                'success': False,
                'message': 'Database error during registration',
                'data': None
            }
        
        # Check if user creation was successful
        user_id = result['data'].get('p_user_id')
        db_success = result['data'].get('p_success')
        db_message = result['data'].get('p_message')
        
        if not db_success or not user_id:
            return {
                'success': False,
                'message': db_message or 'Failed to create user',
                'data': None
            }
        
        # ============================================
        # STEP 4: Generate JWT token
        # ============================================
        
        token_result = generate_token(user_id, username, email)
        token = token_result['token']
        expires_at = token_result['expires_at']
        
        # ============================================
        # STEP 5: Create session in database
        # ============================================
        
        # Get client info
        ip_address = request.remote_addr or '127.0.0.1'
        user_agent = request.headers.get('User-Agent', 'Unknown')
        
        session_result = db.call_procedure(
            'dt_vc_create_session',
            [user_id, token, ip_address, user_agent, expires_at],
            ['p_session_id']
        )
        
        # ============================================
        # STEP 6: Return success response
        # ============================================
        
        return {
            'success': True,
            'message': 'Registration successful',
            'data': {
                'user': {
                    'user_id': user_id,
                    'username': username,
                    'email': email,
                    'display_name': display_name
                },
                'token': token,
                'expires_at': expires_at.isoformat()
            }
        }
    
    
    # ============================================
    # LOGIN
    # ============================================
    
    @staticmethod
    def login(data: dict) -> dict:
        """
        Authenticate a user and create a session.
        
        Parameters:
            data (dict): {
                'email': 'john@example.com',  # or 'username': 'john'
                'password': 'mypassword'
            }
            
        Returns:
            dict: {
                'success': True/False,
                'message': '...',
                'data': {...} or None
            }
            
        PROCESS:
        1. Get user by email/username
        2. Verify password
        3. Generate JWT token
        4. Create session
        5. Update user status to 'online'
        6. Return user data and token
        """
        
        # ============================================
        # STEP 1: Extract login credentials
        # ============================================
        
        email = data.get('email', '').strip().lower()
        username = data.get('username', '').strip().lower()
        password = data.get('password', '')
        
        if not email and not username:
            return {
                'success': False,
                'message': 'Email or username is required',
                'data': None
            }
        
        if not password:
            return {
                'success': False,
                'message': 'Password is required',
                'data': None
            }
        
        # ============================================
        # STEP 2: Get user from database
        # ============================================
        
        user = None
        
        if email:
            user = db.call_procedure_single_result('dt_vc_get_user_by_email', [email])
        elif username:
            user = db.call_procedure_single_result('dt_vc_get_user_by_username', [username])
        
        if not user:
            return {
                'success': False,
                'message': 'Invalid email/username or password',
                'data': None
            }
        
        # Check if user is active
        if not user.get('is_active'):
            return {
                'success': False,
                'message': 'Account is deactivated',
                'data': None
            }
        
        # ============================================
        # STEP 3: Verify password
        # ============================================
        
        stored_hash = user.get('password_hash', '')
        
        if not verify_password(password, stored_hash):
            return {
                'success': False,
                'message': 'Invalid email/username or password',
                'data': None
            }
        
        # ============================================
        # STEP 4: Generate JWT token
        # ============================================
        
        user_id = user['user_id']
        token_result = generate_token(
            user_id, 
            user['username'], 
            user['email']
        )
        token = token_result['token']
        expires_at = token_result['expires_at']
        
        # ============================================
        # STEP 5: Create session in database
        # ============================================
        
        ip_address = request.remote_addr or '127.0.0.1'
        user_agent = request.headers.get('User-Agent', 'Unknown')
        
        db.call_procedure(
            'dt_vc_create_session',
            [user_id, token, ip_address, user_agent, expires_at],
            ['p_session_id']
        )
        
        # ============================================
        # STEP 6: Update user status to online
        # ============================================
        
        db.call_procedure_with_results(
            'dt_vc_update_user_status',
            [user_id, 'online', user_id]
        )
        
        # ============================================
        # STEP 7: Return success response
        # ============================================
        
        return {
            'success': True,
            'message': 'Login successful',
            'data': {
                'user': {
                    'user_id': user_id,
                    'username': user['username'],
                    'email': user['email'],
                    'display_name': user.get('display_name'),
                    'avatar_url': user.get('avatar_url'),
                    'online_status': 'online'
                },
                'token': token,
                'expires_at': expires_at.isoformat()
            }
        }
    
    
    # ============================================
    # LOGOUT
    # ============================================
    
    @staticmethod
    def logout(token: str, user_id: int) -> dict:
        """
        Logout user and invalidate session.
        
        Parameters:
            token (str): The JWT token to invalidate
            user_id (int): The user's ID
            
        Returns:
            dict: {'success': True/False, 'message': '...'}
            
        PROCESS:
        1. Invalidate session in database
        2. Update user status to 'offline'
        """
        
        # Invalidate the session
        db.call_procedure_with_results('dt_vc_invalidate_session', [token])
        
        # Update user status
        db.call_procedure_with_results(
            'dt_vc_update_user_status',
            [user_id, 'offline', user_id]
        )
        
        return {
            'success': True,
            'message': 'Logout successful'
        }
    
    
    # ============================================
    # GET CURRENT USER
    # ============================================
    
    @staticmethod
    def get_me(user: dict) -> dict:
        """
        Get current user profile.
        
        Parameters:
            user (dict): Current user from middleware
            
        Returns:
            dict: User profile data
        """
        
        return {
            'success': True,
            'message': 'User profile retrieved',
            'data': {
                'user': {
                    'user_id': user['user_id'],
                    'username': user['username'],
                    'email': user['email'],
                    'display_name': user.get('display_name'),
                    'avatar_url': user.get('avatar_url'),
                    'online_status': user.get('online_status'),
                    'last_seen': str(user.get('last_seen')) if user.get('last_seen') else None,
                    'created_at': str(user.get('created_dt')) if user.get('created_dt') else None
                }
            }
        }

