"""
============================================
API ROUTES
============================================
Handles all API endpoints.

All routes in this file are prefixed with /api
(configured in __init__.py)

Example:
    @api_bp.route('/health')
    Actually maps to: /api/health
============================================
"""

from flask import jsonify, request
from app.routes import api_bp
from datetime import datetime
import time

# Store server start time for uptime calculation
SERVER_START_TIME = time.time()


@api_bp.route('/health')
def health_check():
    """
    Health Check Endpoint
    
    URL: GET /api/health
    Purpose: Check if server is running
    
    Used for:
    - Monitoring services
    - Load balancers
    - Quick "is it working?" checks
    
    WHAT IS jsonify?
    jsonify() converts a Python dictionary to JSON format
    and sets the correct Content-Type header.
    """
    uptime = time.time() - SERVER_START_TIME
    
    return jsonify({
        'status': 'OK',
        'message': 'WebRTC Video-Chat Server is running!',
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'uptime': f'{uptime:.2f} seconds',
        'framework': 'Flask (Python)'
    })


@api_bp.route('/')
def api_info():
    """
    API Information Endpoint
    
    URL: GET /api
    Purpose: Show available API endpoints
    """
    return jsonify({
        'name': 'WebRTC Video-Chat API',
        'version': '1.0.0',
        'framework': 'Flask (Python)',
        'endpoints': {
            'health': 'GET /api/health',
            'auth': {
                'register': 'POST /api/auth/register',
                'login': 'POST /api/auth/login',
                'me': 'GET /api/auth/me',
                'logout': 'POST /api/auth/logout'
            },
            'rooms': {
                'create': 'POST /api/rooms',
                'list': 'GET /api/rooms',
                'get': 'GET /api/rooms/<code>'
            },
            'contacts': {
                'list': 'GET /api/contacts',
                'add': 'POST /api/contacts',
                'remove': 'DELETE /api/contacts/<id>'
            },
            'calls': {
                'history': 'GET /api/calls'
            }
        }
    })

