"""
============================================
AUTHENTICATION ROUTES
============================================
API endpoints for user authentication.

All routes are prefixed with /api/auth
(configured in __init__.py)

ENDPOINTS:
    POST /api/auth/register  - Create new account
    POST /api/auth/login     - Login and get token
    GET  /api/auth/me        - Get current user (protected)
    POST /api/auth/logout    - Logout (protected)
============================================
"""

from flask import Blueprint, request, jsonify, g
from app.controllers.auth_controller import AuthController
from app.middleware.auth_middleware import token_required

# Create blueprint for auth routes
auth_bp = Blueprint('auth', __name__)


# ============================================
# POST /api/auth/register
# ============================================

@auth_bp.route('/register', methods=['POST'])
def register():
    """
    Register a new user account.
    
    URL: POST /api/auth/register
    
    Request Body (JSON):
        {
            "username": "john",
            "email": "john@example.com",
            "password": "mypassword123",
            "display_name": "John Doe"  // optional
        }
    
    Success Response (201 Created):
        {
            "success": true,
            "message": "Registration successful",
            "data": {
                "user": {
                    "user_id": 1,
                    "username": "john",
                    "email": "john@example.com",
                    "display_name": "John Doe"
                },
                "token": "eyJhbGciOiJIUzI1NiIs...",
                "expires_at": "2026-01-18T12:00:00Z"
            }
        }
    
    Error Response (400 Bad Request):
        {
            "success": false,
            "message": "Username already exists",
            "data": null
        }
    """
    
    # Get JSON data from request body
    data = request.get_json()
    
    if not data:
        return jsonify({
            'success': False,
            'message': 'Request body is required',
            'data': None
        }), 400
    
    # Call controller to handle registration
    result = AuthController.register(data)
    
    # Return appropriate HTTP status code
    if result['success']:
        return jsonify(result), 201  # 201 Created
    else:
        return jsonify(result), 400  # 400 Bad Request


# ============================================
# POST /api/auth/login
# ============================================

@auth_bp.route('/login', methods=['POST'])
def login():
    """
    Login and get JWT token.
    
    URL: POST /api/auth/login
    
    Request Body (JSON):
        {
            "email": "john@example.com",  // or "username": "john"
            "password": "mypassword123"
        }
    
    Success Response (200 OK):
        {
            "success": true,
            "message": "Login successful",
            "data": {
                "user": {
                    "user_id": 1,
                    "username": "john",
                    "email": "john@example.com",
                    "display_name": "John Doe",
                    "avatar_url": null,
                    "online_status": "online"
                },
                "token": "eyJhbGciOiJIUzI1NiIs...",
                "expires_at": "2026-01-18T12:00:00Z"
            }
        }
    
    Error Response (401 Unauthorized):
        {
            "success": false,
            "message": "Invalid email/username or password",
            "data": null
        }
    """
    
    data = request.get_json()
    
    if not data:
        return jsonify({
            'success': False,
            'message': 'Request body is required',
            'data': None
        }), 400
    
    result = AuthController.login(data)
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 401  # 401 Unauthorized


# ============================================
# GET /api/auth/me
# ============================================

@auth_bp.route('/me', methods=['GET'])
@token_required  # This decorator protects the route
def get_me():
    """
    Get current authenticated user's profile.
    
    URL: GET /api/auth/me
    
    Headers Required:
        Authorization: Bearer <token>
    
    Success Response (200 OK):
        {
            "success": true,
            "message": "User profile retrieved",
            "data": {
                "user": {
                    "user_id": 1,
                    "username": "john",
                    "email": "john@example.com",
                    "display_name": "John Doe",
                    "avatar_url": null,
                    "online_status": "online",
                    "last_seen": null,
                    "created_at": "2026-01-11T10:00:00"
                }
            }
        }
    
    Error Response (401 Unauthorized):
        {
            "success": false,
            "message": "Invalid or expired token",
            "error": "Token has expired"
        }
    """
    
    # g.current_user is set by @token_required middleware
    user = g.current_user
    
    result = AuthController.get_me(user)
    
    return jsonify(result), 200


# ============================================
# POST /api/auth/logout
# ============================================

@auth_bp.route('/logout', methods=['POST'])
@token_required
def logout():
    """
    Logout and invalidate the current session.
    
    URL: POST /api/auth/logout
    
    Headers Required:
        Authorization: Bearer <token>
    
    Success Response (200 OK):
        {
            "success": true,
            "message": "Logout successful"
        }
    """
    
    user = g.current_user
    token = g.token
    
    result = AuthController.logout(token, user['user_id'])
    
    return jsonify(result), 200


# ============================================
# GET /api/auth/check
# ============================================

@auth_bp.route('/check', methods=['GET'])
@token_required
def check_auth():
    """
    Check if current token is valid.
    
    URL: GET /api/auth/check
    
    Headers Required:
        Authorization: Bearer <token>
    
    This is a simple endpoint to verify if a token is still valid.
    Useful for frontend to check auth status on page load.
    
    Success Response (200 OK):
        {
            "success": true,
            "message": "Token is valid",
            "data": {
                "user_id": 1,
                "username": "john"
            }
        }
    """
    
    user = g.current_user
    
    return jsonify({
        'success': True,
        'message': 'Token is valid',
        'data': {
            'user_id': user['user_id'],
            'username': user['username']
        }
    }), 200

