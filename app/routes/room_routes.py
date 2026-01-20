"""
============================================
ROOM ROUTES
============================================
API endpoints for room management.

All routes are prefixed with /api/rooms
(configured in __init__.py)

ENDPOINTS:
    POST /api/rooms          - Create new room
    GET  /api/rooms/<code>   - Get room info
    GET  /api/rooms/<code>/participants - Get participants
============================================
"""

from flask import Blueprint, request, jsonify, g
from app.controllers.room_controller import RoomController
from app.middleware.auth_middleware import token_required

# Create blueprint for room routes
room_bp = Blueprint('rooms', __name__)


# ============================================
# POST /api/rooms - Create Room
# ============================================

@room_bp.route('', methods=['POST'])
@token_required
def create_room():
    """
    Create a new video chat room.
    
    URL: POST /api/rooms
    
    Headers Required:
        Authorization: Bearer <token>
    
    Request Body (JSON, all optional):
        {
            "room_name": "My Meeting Room",
            "max_participants": 10,
            "is_private": false,
            "password": null
        }
    
    Success Response (201 Created):
        {
            "success": true,
            "message": "Room created successfully",
            "data": {
                "room_id": 1,
                "room_code": "ABC-123-XYZ",
                "room_name": "My Meeting Room",
                "max_participants": 10,
                "is_private": false,
                "join_url": "/room/ABC-123-XYZ"
            }
        }
    """
    user = g.current_user
    data = request.get_json() or {}
    
    result = RoomController.create_room(user['user_id'], data)
    
    if result['success']:
        return jsonify(result), 201
    else:
        return jsonify(result), 400


# ============================================
# GET /api/rooms/<code> - Get Room Info
# ============================================

@room_bp.route('/<room_code>', methods=['GET'])
def get_room(room_code):
    """
    Get room information by code.
    
    URL: GET /api/rooms/<room_code>
    
    Example: GET /api/rooms/ABC-123-XYZ
    
    Success Response (200 OK):
        {
            "success": true,
            "message": "Room found",
            "data": {
                "room_id": 1,
                "room_code": "ABC-123-XYZ",
                "room_name": "My Meeting Room",
                "host_id": 1,
                "host_name": "John",
                "max_participants": 10,
                "current_participants": 2,
                "is_private": false,
                "room_status": "active",
                "created_at": "2026-01-11 10:00:00"
            }
        }
    
    Error Response (404 Not Found):
        {
            "success": false,
            "message": "Room not found",
            "data": null
        }
    """
    result = RoomController.get_room(room_code)
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 404


# ============================================
# GET /api/rooms/<code>/participants
# ============================================

@room_bp.route('/<room_code>/participants', methods=['GET'])
def get_room_participants(room_code):
    """
    Get list of participants in a room.
    
    URL: GET /api/rooms/<room_code>/participants
    
    Success Response (200 OK):
        {
            "success": true,
            "message": "2 participant(s) in room",
            "data": {
                "room_code": "ABC-123-XYZ",
                "participants": [
                    {
                        "user_id": 1,
                        "username": "john",
                        "display_name": "John Doe",
                        "is_audio_on": true,
                        "is_video_on": true
                    }
                ],
                "count": 2
            }
        }
    """
    result = RoomController.get_room_participants(room_code)
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 404


# ============================================
# POST /api/rooms/<code>/verify-password
# ============================================

@room_bp.route('/<room_code>/verify-password', methods=['POST'])
def verify_room_password(room_code):
    """
    Verify password for a private room.
    
    URL: POST /api/rooms/<room_code>/verify-password
    
    Request Body:
        {
            "password": "room_password"
        }
    
    Success Response (200 OK):
        {
            "success": true,
            "message": "Password correct"
        }
    
    Error Response (401 Unauthorized):
        {
            "success": false,
            "message": "Incorrect password"
        }
    """
    data = request.get_json() or {}
    password = data.get('password', '')
    
    result = RoomController.verify_room_password(room_code, password)
    
    if result['success']:
        return jsonify(result), 200
    else:
        return jsonify(result), 401

