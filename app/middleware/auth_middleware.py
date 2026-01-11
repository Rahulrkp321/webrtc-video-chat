"""
============================================
AUTHENTICATION MIDDLEWARE
============================================
Middleware to protect routes that require authentication.

WHAT IS MIDDLEWARE?
-------------------
Middleware is code that runs BEFORE your route handler.
It can:
1. Check if user is authenticated
2. Add data to the request
3. Block the request if conditions aren't met

WHAT IS A DECORATOR?
--------------------
A decorator is a function that wraps another function.
It adds behavior without modifying the original function.

Example without decorator:
    def my_route():
        return "Hello"
    
    # Manually wrap it
    my_route = check_auth(my_route)

Example with decorator (cleaner!):
    @check_auth
    def my_route():
        return "Hello"

HOW @token_required WORKS:
--------------------------
1. Client sends request with header: Authorization: Bearer <token>
2. Middleware extracts the token
3. Middleware validates the token
4. If valid: Get user info, add to request, continue to route
5. If invalid: Return 401 Unauthorized error

REQUEST FLOW:
    Client Request
         ↓
    @token_required (middleware)
         ↓
    Is token valid?
         ├── NO → Return 401 Error
         └── YES → Continue to route handler
                        ↓
                   Route Handler
                        ↓
                   Response to Client
============================================
"""

from functools import wraps
from flask import request, jsonify, g
from app.utils.jwt_helper import decode_token, get_token_from_header
from app.config.database import db


def token_required(f):
    """
    Decorator that requires a valid JWT token.
    
    Usage:
        @api_bp.route('/protected')
        @token_required
        def protected_route():
            # Access current user via g.current_user
            user = g.current_user
            return jsonify({'message': f'Hello {user["username"]}!'})
    
    What it does:
        1. Gets token from Authorization header
        2. Validates the token
        3. Fetches user from database
        4. Adds user to Flask's 'g' object
        5. Calls the original route function
    
    If token is invalid or missing:
        Returns 401 Unauthorized with error message
    
    WHAT IS 'g'?
    Flask's 'g' object is a request-scoped storage.
    Data stored in 'g' is available during that request only.
    We use it to pass the current user to route handlers.
    """
    
    @wraps(f)  # Preserves original function's name and docstring
    def decorated_function(*args, **kwargs):
        """
        The wrapper function that runs before the actual route.
        """
        
        # ============================================
        # STEP 1: Get token from header
        # ============================================
        
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return jsonify({
                'success': False,
                'message': 'Missing Authorization header',
                'error': 'Please provide Authorization header with format: Bearer <token>'
            }), 401
        
        token = get_token_from_header(auth_header)
        
        if not token:
            return jsonify({
                'success': False,
                'message': 'Invalid Authorization header format',
                'error': 'Format should be: Bearer <token>'
            }), 401
        
        # ============================================
        # STEP 2: Validate the token
        # ============================================
        
        result = decode_token(token)
        
        if not result['valid']:
            return jsonify({
                'success': False,
                'message': 'Invalid or expired token',
                'error': result['error']
            }), 401
        
        # ============================================
        # STEP 3: Get user from database
        # ============================================
        
        user_id = result['payload'].get('user_id')
        
        if not user_id:
            return jsonify({
                'success': False,
                'message': 'Invalid token payload',
                'error': 'Token does not contain user_id'
            }), 401
        
        # Call stored procedure to get user
        user = db.call_procedure_single_result('dt_vc_get_user_by_id', [user_id])
        
        if not user:
            return jsonify({
                'success': False,
                'message': 'User not found',
                'error': 'The user associated with this token no longer exists'
            }), 401
        
        # Check if user is active
        if not user.get('is_active'):
            return jsonify({
                'success': False,
                'message': 'Account deactivated',
                'error': 'Your account has been deactivated'
            }), 401
        
        # ============================================
        # STEP 4: Verify session in database
        # ============================================
        
        # Check if session exists and is valid
        session_result = db.call_procedure_with_results('dt_vc_get_session', [token])
        
        if not session_result['success'] or not session_result['data']:
            return jsonify({
                'success': False,
                'message': 'Session expired or invalid',
                'error': 'Please login again'
            }), 401
        
        # ============================================
        # STEP 5: Store user in request context
        # ============================================
        
        # Add user to Flask's g object
        g.current_user = user
        g.token = token
        
        # ============================================
        # STEP 6: Call the actual route function
        # ============================================
        
        return f(*args, **kwargs)
    
    return decorated_function


def get_current_user():
    """
    Get the current authenticated user.
    
    Returns:
        dict: Current user data from the database
        None: If no user is authenticated
    
    Usage:
        from app.middleware import get_current_user
        
        @api_bp.route('/profile')
        @token_required
        def profile():
            user = get_current_user()
            return jsonify({'user': user})
    """
    return getattr(g, 'current_user', None)


def optional_auth(f):
    """
    Decorator that optionally authenticates the user.
    
    Unlike @token_required, this doesn't block the request
    if no token is provided. It just sets g.current_user
    to the user if authenticated, or None if not.
    
    Useful for routes that work both with and without login.
    
    Usage:
        @api_bp.route('/posts')
        @optional_auth
        def get_posts():
            user = g.current_user
            if user:
                # Show personalized posts
                return get_personalized_posts(user['user_id'])
            else:
                # Show public posts
                return get_public_posts()
    """
    
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Default: no user
        g.current_user = None
        g.token = None
        
        # Try to authenticate
        auth_header = request.headers.get('Authorization')
        
        if auth_header:
            token = get_token_from_header(auth_header)
            
            if token:
                result = decode_token(token)
                
                if result['valid']:
                    user_id = result['payload'].get('user_id')
                    
                    if user_id:
                        user = db.call_procedure_single_result(
                            'dt_vc_get_user_by_id', 
                            [user_id]
                        )
                        
                        if user and user.get('is_active'):
                            g.current_user = user
                            g.token = token
        
        # Continue to route (whether authenticated or not)
        return f(*args, **kwargs)
    
    return decorated_function

