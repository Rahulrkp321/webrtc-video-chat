"""
============================================
ROOM CONTROLLER
============================================
Handles room creation and management via REST API.

Note: Most room operations happen through Socket.IO (events.py),
but we also provide REST endpoints for:
- Creating rooms before joining
- Getting room info
- Listing user's rooms
============================================
"""

import random
import string
from flask import request
from app.config.database import db


class RoomController:
    """
    Handles room-related operations.
    """
    
    @staticmethod
    def generate_room_code():
        """
        Generate a unique room code.
        Format: XXX-XXX-XXX (e.g., ABC-123-XYZ)
        
        Returns:
            str: Generated room code
        """
        chars = string.ascii_uppercase + string.digits
        parts = []
        for _ in range(3):
            part = ''.join(random.choice(chars) for _ in range(3))
            parts.append(part)
        return '-'.join(parts)
    
    
    @staticmethod
    def create_room(user_id: int, data: dict) -> dict:
        """
        Create a new video chat room.
        
        Parameters:
            user_id (int): ID of the user creating the room
            data (dict): {
                'room_name': 'My Room',  # optional
                'max_participants': 10,   # optional
                'is_private': False,      # optional
                'password': None          # optional
            }
        
        Returns:
            dict: {success, message, data}
        """
        # Generate room code
        room_code = RoomController.generate_room_code()
        
        # Extract data
        room_name = data.get('room_name', f'Room {room_code}')
        max_participants = data.get('max_participants', 10)
        is_private = 1 if data.get('is_private') else 0
        password = data.get('password')
        
        # Hash password if provided
        password_hash = None
        if password:
            from app.utils.password import hash_password
            password_hash = hash_password(password)
        
        # Create room in database
        result = db.call_procedure(
            'dt_vc_create_room',
            [room_code, room_name, user_id, max_participants, is_private, password_hash],
            ['p_room_id', 'p_success', 'p_message']
        )
        
        if not result['success']:
            return {
                'success': False,
                'message': 'Database error',
                'data': None
            }
        
        room_id = result['data'].get('p_room_id')
        db_success = result['data'].get('p_success')
        db_message = result['data'].get('p_message')
        
        if not db_success or not room_id:
            return {
                'success': False,
                'message': db_message or 'Failed to create room',
                'data': None
            }
        
        return {
            'success': True,
            'message': 'Room created successfully',
            'data': {
                'room_id': room_id,
                'room_code': room_code,
                'room_name': room_name,
                'max_participants': max_participants,
                'is_private': bool(is_private),
                'join_url': f'/room/{room_code}'
            }
        }
    
    
    @staticmethod
    def get_room(room_code: str) -> dict:
        """
        Get room information by code.
        
        Parameters:
            room_code (str): The room code (e.g., 'ABC-123-XYZ')
        
        Returns:
            dict: {success, message, data}
        """
        room_code = room_code.upper()
        
        room = db.call_procedure_single_result('dt_vc_get_room_by_code', [room_code])
        
        if not room:
            return {
                'success': False,
                'message': 'Room not found',
                'data': None
            }
        
        return {
            'success': True,
            'message': 'Room found',
            'data': {
                'room_id': room['room_id'],
                'room_code': room['room_code'],
                'room_name': room.get('room_name'),
                'host_id': room.get('host_user_id'),
                'host_name': room.get('host_name'),
                'max_participants': room.get('max_participants'),
                'current_participants': room.get('current_participants', 0),
                'is_private': bool(room.get('is_private')),
                'room_status': room.get('room_status'),
                'created_at': str(room.get('created_dt')) if room.get('created_dt') else None
            }
        }
    
    
    @staticmethod
    def get_room_participants(room_code: str) -> dict:
        """
        Get list of participants in a room.
        
        Parameters:
            room_code (str): The room code
        
        Returns:
            dict: {success, message, data}
        """
        room_code = room_code.upper()
        
        # First get room to get room_id
        room = db.call_procedure_single_result('dt_vc_get_room_by_code', [room_code])
        
        if not room:
            return {
                'success': False,
                'message': 'Room not found',
                'data': None
            }
        
        # Get participants
        result = db.call_procedure_with_results(
            'dt_vc_get_room_participants',
            [room['room_id']]
        )
        
        participants = result['data'] if result['success'] else []
        
        return {
            'success': True,
            'message': f'{len(participants)} participant(s) in room',
            'data': {
                'room_code': room_code,
                'participants': participants,
                'count': len(participants)
            }
        }
    
    
    @staticmethod
    def verify_room_password(room_code: str, password: str) -> dict:
        """
        Verify password for a private room.
        
        Parameters:
            room_code (str): The room code
            password (str): Password to verify
        
        Returns:
            dict: {success, message}
        """
        room_code = room_code.upper()
        
        # Get room with password hash
        room = db.call_procedure_single_result('dt_vc_get_room_by_code', [room_code])
        
        if not room:
            return {
                'success': False,
                'message': 'Room not found'
            }
        
        # If room is not private, no password needed
        if not room.get('is_private'):
            return {
                'success': True,
                'message': 'Room is public, no password required'
            }
        
        # Verify password
        stored_hash = room.get('password_hash')
        
        if not stored_hash:
            return {
                'success': True,
                'message': 'Room has no password set'
            }
        
        from app.utils.password import verify_password
        
        if verify_password(password, stored_hash):
            return {
                'success': True,
                'message': 'Password correct'
            }
        else:
            return {
                'success': False,
                'message': 'Incorrect password'
            }

