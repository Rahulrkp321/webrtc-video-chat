"""
============================================
SOCKET.IO EVENT HANDLERS
============================================
Handles real-time events for video chat signaling.

WEBRTC SIGNALING FLOW:
----------------------

1. USER JOINS ROOM
   Client → 'join_room' → Server
   Server → 'user_joined' → All users in room

2. INITIATING A CALL (WebRTC Offer)
   Caller creates "offer" (SDP - Session Description Protocol)
   Caller → 'offer' → Server → 'offer' → Callee

3. ANSWERING A CALL (WebRTC Answer)
   Callee creates "answer" (SDP)
   Callee → 'answer' → Server → 'answer' → Caller

4. ICE CANDIDATES (Connection paths)
   Both peers discover ways to connect (ICE = Interactive Connectivity Establishment)
   Peer → 'ice_candidate' → Server → 'ice_candidate' → Other Peer

5. USER LEAVES ROOM
   Client → 'leave_room' → Server
   Server → 'user_left' → All users in room

SOCKET.IO CONCEPTS:
-------------------
- emit(): Send event to ONE client
- broadcast.emit(): Send to ALL clients EXCEPT sender
- room: A group of sockets (like a chat room)
- join_room(): Add socket to a room
- leave_room(): Remove socket from a room
============================================
"""

from flask import request
from flask_socketio import emit, join_room, leave_room, rooms
from app import socketio
from app.config.database import db
from app.utils.jwt_helper import decode_token, get_token_from_header
import json

# Store connected users: {socket_id: {user_id, username, room_code}}
connected_users = {}

# Store rooms: {room_code: {users: [], host_id, created_at}}
active_rooms = {}


def register_socket_events(socketio_instance):
    """
    Register all Socket.IO event handlers.
    Called from app/__init__.py
    """
    pass  # Events are registered with decorators below


# ============================================
# CONNECTION EVENTS
# ============================================

@socketio.on('connect')
def handle_connect():
    """
    Called when a client connects to Socket.IO.
    
    At this point, we don't know who the user is yet.
    They need to authenticate with 'authenticate' event.
    """
    print(f'🔌 Client connected: {request.sid}')
    
    # Send welcome message
    emit('connected', {
        'message': 'Connected to WebRTC Video-Chat server',
        'socket_id': request.sid
    })


@socketio.on('disconnect')
def handle_disconnect():
    """
    Called when a client disconnects.
    
    Clean up:
    1. Remove from connected_users
    2. Remove from any rooms
    3. Notify other users in the room
    """
    socket_id = request.sid
    print(f'🔌 Client disconnected: {socket_id}')
    
    # Check if user was in a room
    if socket_id in connected_users:
        user_info = connected_users[socket_id]
        room_code = user_info.get('room_code')
        
        if room_code:
            # Notify others in the room
            emit('user_left', {
                'user_id': user_info.get('user_id'),
                'username': user_info.get('username'),
                'socket_id': socket_id,
                'message': f"{user_info.get('username')} disconnected"
            }, room=room_code)
            
            # Remove from active_rooms
            if room_code in active_rooms:
                active_rooms[room_code]['users'] = [
                    u for u in active_rooms[room_code]['users']
                    if u['socket_id'] != socket_id
                ]
                
                # If room is empty, mark it as ended
                if not active_rooms[room_code]['users']:
                    del active_rooms[room_code]
        
        # Remove from connected_users
        del connected_users[socket_id]


# ============================================
# AUTHENTICATION
# ============================================

@socketio.on('authenticate')
def handle_authenticate(data):
    """
    Authenticate the socket connection with JWT token.
    
    Client sends:
        {token: 'jwt_token_here'}
    
    Server responds:
        {success: true, user: {...}}
        or
        {success: false, error: '...'}
    """
    token = data.get('token')
    
    if not token:
        emit('authenticated', {
            'success': False,
            'error': 'Token is required'
        })
        return
    
    # Validate token
    result = decode_token(token)
    
    if not result['valid']:
        emit('authenticated', {
            'success': False,
            'error': result['error']
        })
        return
    
    # Get user info from token
    payload = result['payload']
    user_id = payload.get('user_id')
    username = payload.get('username')
    
    # Store in connected_users
    connected_users[request.sid] = {
        'user_id': user_id,
        'username': username,
        'token': token,
        'room_code': None
    }
    
    print(f'✅ User authenticated: {username} (socket: {request.sid})')
    
    emit('authenticated', {
        'success': True,
        'user': {
            'user_id': user_id,
            'username': username,
            'socket_id': request.sid
        }
    })


# ============================================
# ROOM EVENTS
# ============================================

@socketio.on('create_room')
def handle_create_room(data):
    """
    Create a new video chat room.
    
    Client sends:
        {room_code: 'ABC-123-XYZ', room_name: 'My Room'}
    
    Server responds:
        {success: true, room: {...}}
    """
    socket_id = request.sid
    
    # Check if authenticated
    if socket_id not in connected_users:
        emit('room_created', {
            'success': False,
            'error': 'Not authenticated'
        })
        return
    
    user_info = connected_users[socket_id]
    room_code = data.get('room_code', '').upper()
    room_name = data.get('room_name', f"Room {room_code}")
    
    if not room_code:
        emit('room_created', {
            'success': False,
            'error': 'Room code is required'
        })
        return
    
    # Check if room already exists
    if room_code in active_rooms:
        emit('room_created', {
            'success': False,
            'error': 'Room already exists'
        })
        return
    
    # Create room in database
    db_result = db.call_procedure(
        'dt_vc_create_room',
        [room_code, room_name, user_info['user_id'], 10, 0, None],
        ['p_room_id', 'p_success', 'p_message']
    )
    
    if not db_result['success'] or not db_result['data'].get('p_success'):
        emit('room_created', {
            'success': False,
            'error': db_result['data'].get('p_message', 'Failed to create room')
        })
        return
    
    room_id = db_result['data'].get('p_room_id')
    
    # Create room in memory
    active_rooms[room_code] = {
        'room_id': room_id,
        'room_code': room_code,
        'room_name': room_name,
        'host_id': user_info['user_id'],
        'host_username': user_info['username'],
        'users': []
    }
    
    print(f'🏠 Room created: {room_code} by {user_info["username"]}')
    
    emit('room_created', {
        'success': True,
        'room': {
            'room_id': room_id,
            'room_code': room_code,
            'room_name': room_name,
            'host_id': user_info['user_id']
        }
    })


@socketio.on('join_room')
def handle_join_room(data):
    """
    Join an existing video chat room.
    
    Client sends:
        {room_code: 'ABC-123-XYZ'}
    
    Server responds to joiner:
        {success: true, room: {...}, users: [...]}
    
    Server broadcasts to room:
        'user_joined' event with new user info
    """
    socket_id = request.sid
    
    # Check if authenticated
    if socket_id not in connected_users:
        emit('room_joined', {
            'success': False,
            'error': 'Not authenticated'
        })
        return
    
    user_info = connected_users[socket_id]
    room_code = data.get('room_code', '').upper()
    
    if not room_code:
        emit('room_joined', {
            'success': False,
            'error': 'Room code is required'
        })
        return
    
    # Check if room exists in database
    room_data = db.call_procedure_single_result('dt_vc_get_room_by_code', [room_code])
    
    if not room_data:
        emit('room_joined', {
            'success': False,
            'error': 'Room not found'
        })
        return
    
    # Check room status
    if room_data.get('room_status') == 'ended':
        emit('room_joined', {
            'success': False,
            'error': 'Room has ended'
        })
        return
    
    # Check if room is full
    current_count = room_data.get('current_participants', 0)
    max_participants = room_data.get('max_participants', 10)
    
    if current_count >= max_participants:
        emit('room_joined', {
            'success': False,
            'error': 'Room is full'
        })
        return
    
    # Join room in database
    db_result = db.call_procedure(
        'dt_vc_join_room',
        [room_data['room_id'], user_info['user_id']],
        ['p_participant_id', 'p_success', 'p_message']
    )
    
    # Create room in memory if not exists
    if room_code not in active_rooms:
        active_rooms[room_code] = {
            'room_id': room_data['room_id'],
            'room_code': room_code,
            'room_name': room_data.get('room_name', room_code),
            'host_id': room_data.get('host_user_id'),
            'host_username': room_data.get('host_name'),
            'users': []
        }
    
    # Add user to room
    user_entry = {
        'socket_id': socket_id,
        'user_id': user_info['user_id'],
        'username': user_info['username']
    }
    
    active_rooms[room_code]['users'].append(user_entry)
    connected_users[socket_id]['room_code'] = room_code
    
    # Join Socket.IO room
    join_room(room_code)
    
    # Get existing users in room (for the joining user)
    existing_users = [u for u in active_rooms[room_code]['users'] if u['socket_id'] != socket_id]
    
    print(f'👤 {user_info["username"]} joined room {room_code}')
    
    # Send success to the joining user
    emit('room_joined', {
        'success': True,
        'room': {
            'room_id': room_data['room_id'],
            'room_code': room_code,
            'room_name': room_data.get('room_name'),
            'host_id': room_data.get('host_user_id'),
            'host_name': room_data.get('host_name')
        },
        'users': existing_users,
        'user_count': len(active_rooms[room_code]['users'])
    })
    
    # Notify other users in the room
    emit('user_joined', {
        'user_id': user_info['user_id'],
        'username': user_info['username'],
        'socket_id': socket_id,
        'user_count': len(active_rooms[room_code]['users'])
    }, room=room_code, include_self=False)


@socketio.on('leave_room')
def handle_leave_room(data):
    """
    Leave the current room.
    
    Client sends:
        {room_code: 'ABC-123-XYZ'}
    """
    socket_id = request.sid
    
    if socket_id not in connected_users:
        return
    
    user_info = connected_users[socket_id]
    room_code = data.get('room_code', '').upper() or user_info.get('room_code')
    
    if not room_code:
        return
    
    # Leave database
    if room_code in active_rooms:
        room = active_rooms[room_code]
        db.call_procedure_with_results(
            'dt_vc_leave_room',
            [room.get('room_id'), user_info['user_id']]
        )
    
    # Leave Socket.IO room
    leave_room(room_code)
    
    # Update memory
    if room_code in active_rooms:
        active_rooms[room_code]['users'] = [
            u for u in active_rooms[room_code]['users']
            if u['socket_id'] != socket_id
        ]
        
        # Notify others
        emit('user_left', {
            'user_id': user_info['user_id'],
            'username': user_info['username'],
            'socket_id': socket_id,
            'user_count': len(active_rooms[room_code]['users'])
        }, room=room_code)
        
        # Clean up empty room
        if not active_rooms[room_code]['users']:
            del active_rooms[room_code]
    
    connected_users[socket_id]['room_code'] = None
    
    print(f'👋 {user_info["username"]} left room {room_code}')
    
    emit('room_left', {'success': True})


@socketio.on('get_room_users')
def handle_get_room_users(data):
    """
    Get list of users in a room.
    """
    room_code = data.get('room_code', '').upper()
    
    if room_code in active_rooms:
        emit('room_users', {
            'room_code': room_code,
            'users': active_rooms[room_code]['users'],
            'user_count': len(active_rooms[room_code]['users'])
        })
    else:
        emit('room_users', {
            'room_code': room_code,
            'users': [],
            'user_count': 0
        })


# ============================================
# WEBRTC SIGNALING EVENTS
# ============================================

@socketio.on('offer')
def handle_offer(data):
    """
    Forward WebRTC offer to target user.
    
    WHAT IS AN OFFER?
    An offer contains SDP (Session Description Protocol) which describes:
    - What media the sender can send (video, audio)
    - Codecs supported
    - Network information
    
    Client sends:
        {
            target_socket_id: 'socket_id_of_recipient',
            sdp: {type: 'offer', sdp: '...'}
        }
    """
    socket_id = request.sid
    
    if socket_id not in connected_users:
        return
    
    user_info = connected_users[socket_id]
    target_socket_id = data.get('target_socket_id')
    sdp = data.get('sdp')
    
    if not target_socket_id or not sdp:
        return
    
    print(f'📤 Offer from {user_info["username"]} to {target_socket_id}')
    
    # Forward offer to target
    emit('offer', {
        'from_socket_id': socket_id,
        'from_user_id': user_info['user_id'],
        'from_username': user_info['username'],
        'sdp': sdp
    }, room=target_socket_id)


@socketio.on('answer')
def handle_answer(data):
    """
    Forward WebRTC answer to caller.
    
    WHAT IS AN ANSWER?
    An answer is the response to an offer, also containing SDP.
    It confirms what media formats both peers will use.
    
    Client sends:
        {
            target_socket_id: 'socket_id_of_caller',
            sdp: {type: 'answer', sdp: '...'}
        }
    """
    socket_id = request.sid
    
    if socket_id not in connected_users:
        return
    
    user_info = connected_users[socket_id]
    target_socket_id = data.get('target_socket_id')
    sdp = data.get('sdp')
    
    if not target_socket_id or not sdp:
        return
    
    print(f'📥 Answer from {user_info["username"]} to {target_socket_id}')
    
    # Forward answer to target
    emit('answer', {
        'from_socket_id': socket_id,
        'from_user_id': user_info['user_id'],
        'from_username': user_info['username'],
        'sdp': sdp
    }, room=target_socket_id)


@socketio.on('ice_candidate')
def handle_ice_candidate(data):
    """
    Forward ICE candidate to target user.
    
    WHAT ARE ICE CANDIDATES?
    ICE (Interactive Connectivity Establishment) candidates are
    possible network paths to reach a peer:
    - Host candidates (local IP)
    - Server reflexive (public IP via STUN)
    - Relay (through TURN server)
    
    Both peers exchange candidates until they find a path that works.
    
    Client sends:
        {
            target_socket_id: 'socket_id_of_peer',
            candidate: {candidate: '...', sdpMid: '...', sdpMLineIndex: 0}
        }
    """
    socket_id = request.sid
    
    if socket_id not in connected_users:
        return
    
    user_info = connected_users[socket_id]
    target_socket_id = data.get('target_socket_id')
    candidate = data.get('candidate')
    
    if not target_socket_id or not candidate:
        return
    
    # Forward ICE candidate to target
    emit('ice_candidate', {
        'from_socket_id': socket_id,
        'from_user_id': user_info['user_id'],
        'candidate': candidate
    }, room=target_socket_id)


# ============================================
# MEDIA CONTROL EVENTS
# ============================================

@socketio.on('toggle_audio')
def handle_toggle_audio(data):
    """
    Notify room when user toggles audio.
    """
    socket_id = request.sid
    
    if socket_id not in connected_users:
        return
    
    user_info = connected_users[socket_id]
    room_code = user_info.get('room_code')
    is_audio_on = data.get('is_audio_on', True)
    
    if room_code:
        emit('user_audio_toggle', {
            'user_id': user_info['user_id'],
            'username': user_info['username'],
            'socket_id': socket_id,
            'is_audio_on': is_audio_on
        }, room=room_code, include_self=False)


@socketio.on('toggle_video')
def handle_toggle_video(data):
    """
    Notify room when user toggles video.
    """
    socket_id = request.sid
    
    if socket_id not in connected_users:
        return
    
    user_info = connected_users[socket_id]
    room_code = user_info.get('room_code')
    is_video_on = data.get('is_video_on', True)
    
    if room_code:
        emit('user_video_toggle', {
            'user_id': user_info['user_id'],
            'username': user_info['username'],
            'socket_id': socket_id,
            'is_video_on': is_video_on
        }, room=room_code, include_self=False)


# ============================================
# CHAT EVENTS (Bonus)
# ============================================

@socketio.on('chat_message')
def handle_chat_message(data):
    """
    Send a chat message to the room.
    """
    socket_id = request.sid
    
    if socket_id not in connected_users:
        return
    
    user_info = connected_users[socket_id]
    room_code = user_info.get('room_code')
    message = data.get('message', '').strip()
    
    if room_code and message:
        emit('chat_message', {
            'user_id': user_info['user_id'],
            'username': user_info['username'],
            'message': message,
            'timestamp': data.get('timestamp')
        }, room=room_code)


# ============================================
# UTILITY FUNCTIONS
# ============================================

def get_room_info(room_code):
    """Get information about a room."""
    if room_code in active_rooms:
        return active_rooms[room_code]
    return None


def get_user_by_socket(socket_id):
    """Get user info by socket ID."""
    return connected_users.get(socket_id)

