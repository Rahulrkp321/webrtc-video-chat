# 📚 WebRTC Video-Chat Development Log (Python/Flask)

## Project Overview

| Item | Value |
|------|-------|
| **Application Name** | WebRTC Video-Chat |
| **Database Name** | RTC_Video_Chat_DB |
| **Framework** | Python 3.13 + Flask |
| **Language** | English |
| **Max Participants** | Multiple (10 default) |

---

## Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Runtime** | Python 3.13+ | Server-side programming |
| **Web Framework** | Flask 3.1.0 | HTTP routing and middleware |
| **Real-time** | Flask-SocketIO | WebSocket communication for signaling |
| **Database** | MySQL 8.0+ | Data persistence |
| **DB Driver** | PyMySQL | MySQL connector for Python |
| **Authentication** | PyJWT + bcrypt | Token-based auth with secure passwords |
| **Frontend** | HTML/CSS/JavaScript | User interface |
| **WebRTC** | Browser APIs | Peer-to-peer video/audio |

---

## Database Design Rules

All database access follows these strict rules:

1. **Stored Procedures Only** - No inline SQL in application code
2. **Procedure Prefix** - All procedures prefixed with `dt_vc_`
3. **Numeric Primary Keys** - Auto-increment INT (no UUIDs)
4. **Audit Fields** - Every table includes:
   - `is_active` (TINYINT) - Whether record is active
   - `is_deleted` (TINYINT) - Soft delete flag
   - `remarks` (TEXT) - Notes about the record
   - `created_dt` (DATETIME) - Creation timestamp
   - `created_by` (INT) - Creator user ID
   - `updated_dt` (DATETIME) - Last update timestamp
   - `updated_by` (INT) - Last updater user ID

---

## Day-by-Day Development Plan

| Day | Focus | Status |
|-----|-------|--------|
| Day 1 | Environment Setup + Flask Server | ✅ Complete |
| Day 2 | Database Schema + Stored Procedures | ✅ Complete |
| Day 3 | User Authentication API | ✅ Complete |
| Day 4 | Authentication UI (Login/Register) | ✅ Complete |
| Day 5 | Signaling Server + Room Management | ✅ Complete |
| Day 6 | WebRTC Core Implementation | ⏳ Pending |
| Day 7 | Complete Video Call Flow | ⏳ Pending |
| Day 8 | Call Controls + Features | ⏳ Pending |
| Day 9 | Contact List + Call History | ⏳ Pending |
| Day 10 | Group Video Calls | ⏳ Pending |
| Day 11 | Polish + Testing | ⏳ Pending |
| Day 12 | Final Documentation + Deployment | ⏳ Pending |

---

# 📅 Day 1: Environment Setup + Flask Server

## Goals
- ✅ Set up Python virtual environment
- ✅ Install Flask and dependencies
- ✅ Create project structure
- ✅ Build basic Flask server
- ✅ Create landing page
- ✅ Test health endpoint

## What We Built

### 1. Project Structure

```
webrtc-video-chat/
├── app/                          # Main application package
│   ├── __init__.py              # Flask app factory
│   ├── config/                  # Configuration modules
│   │   ├── __init__.py
│   │   └── database.py          # MySQL connection pool
│   ├── routes/                  # Route definitions
│   │   ├── __init__.py          # Blueprint definitions
│   │   ├── main_routes.py       # Page routes
│   │   └── api_routes.py        # API endpoints
│   ├── controllers/             # Business logic (Day 3+)
│   ├── models/                  # Data models (Day 3+)
│   ├── middleware/              # Auth middleware (Day 3+)
│   ├── socket/                  # SocketIO handlers (Day 5+)
│   ├── templates/               # HTML templates
│   │   ├── index.html           # Landing page
│   │   └── ...                  # Other pages
│   └── static/                  # Static files
│       ├── css/                 # Stylesheets
│       └── js/                  # JavaScript
├── database/                    # SQL files
│   ├── schema.sql               # Table definitions
│   └── stored_procedures.sql    # All stored procedures
├── tests/                       # Test files (Day 11+)
├── venv/                        # Virtual environment
├── .env                         # Environment variables (gitignored)
├── .env.example                 # Example env file
├── .gitignore                   # Git ignore rules
├── requirements.txt             # Python dependencies
└── run.py                       # Application entry point
```

### 2. Key Files Explained

#### `run.py` - Application Entry Point

```python
# This is the file you run to start the server
# Command: python run.py

import eventlet
eventlet.monkey_patch()  # Enable async support

from app import create_app, socketio
from app.config.database import db

app = create_app()

def main():
    # Test database connection
    db.test_connection()
    
    # Start server with SocketIO
    socketio.run(app, host='0.0.0.0', port=3000)

if __name__ == '__main__':
    main()
```

#### `app/__init__.py` - Application Factory

```python
# Creates and configures the Flask application
# Using the "factory pattern" for flexibility

from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO

socketio = SocketIO()

def create_app():
    app = Flask(__name__)
    
    # Load configuration from environment
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY')
    
    # Initialize extensions
    CORS(app)
    socketio.init_app(app)
    
    # Register blueprints (route groups)
    from app.routes import main_bp, api_bp
    app.register_blueprint(main_bp)
    app.register_blueprint(api_bp, url_prefix='/api')
    
    return app
```

#### `app/config/database.py` - Database Connection

```python
# Manages MySQL database connections
# ALL database access uses stored procedures!

import pymysql
from pymysql.cursors import DictCursor

class Database:
    def get_connection(self):
        return pymysql.connect(
            host=os.getenv('DB_HOST'),
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            database=os.getenv('DB_NAME'),
            cursorclass=DictCursor
        )
    
    def call_procedure(self, name, params):
        # Execute stored procedure
        conn = self.get_connection()
        cursor = conn.cursor()
        cursor.execute(f"CALL {name}(...)", params)
        return cursor.fetchall()
```

### 3. Tested Endpoints

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/` | GET | Landing page | ✅ Working |
| `/api` | GET | API information | ✅ Working |
| `/api/health` | GET | Health check | ✅ Working |

### 4. How to Run

```bash
# 1. Navigate to project
cd ~/webrtc-video-chat

# 2. Activate virtual environment
source venv/bin/activate

# 3. Run the server
python run.py

# 4. Open in browser
# http://localhost:3000
```

---

# 📅 Day 2: Database Schema + Stored Procedures

## Goals
- ✅ Design database schema
- ✅ Create all tables with audit fields
- ✅ Create stored procedures with dt_vc_ prefix
- ✅ Document database design

## Database Tables

| # | Table | Purpose | Key Columns |
|---|-------|---------|-------------|
| 1 | `users` | User accounts | user_id, username, email, password_hash |
| 2 | `sessions` | Login sessions | session_id, user_id, token, expires_at |
| 3 | `rooms` | Video chat rooms | room_id, room_code, host_user_id |
| 4 | `room_participants` | Who's in each room | participant_id, room_id, user_id |
| 5 | `contacts` | User contact lists | contact_id, user_id, contact_user_id |
| 6 | `call_logs` | Call history | call_id, caller_id, callee_id, duration |
| 7 | `ice_candidates` | WebRTC ICE data | candidate_id, room_id, candidate |

## Stored Procedures (dt_vc_ prefix)

| Category | Procedure | Purpose |
|----------|-----------|---------|
| **Users** | dt_vc_create_user | Register new user |
| | dt_vc_get_user_by_email | Login lookup |
| | dt_vc_get_user_by_id | Get user profile |
| | dt_vc_update_user_status | Set online/offline |
| **Sessions** | dt_vc_create_session | Create login session |
| | dt_vc_get_session | Validate token |
| | dt_vc_invalidate_session | Logout |
| **Rooms** | dt_vc_create_room | Create video room |
| | dt_vc_get_room_by_code | Find room |
| | dt_vc_join_room | Join a room |
| | dt_vc_leave_room | Leave a room |
| | dt_vc_get_room_participants | List users in room |
| **Contacts** | dt_vc_add_contact | Add contact |
| | dt_vc_get_contacts | List contacts |
| | dt_vc_remove_contact | Remove contact |
| **Calls** | dt_vc_create_call_log | Start call record |
| | dt_vc_update_call_log | Update call status |
| | dt_vc_get_call_history | Get call history |

## How to Set Up Database

```bash
# 1. Make sure MySQL is running
brew services start mysql

# 2. Connect to MySQL
mysql -u root -p
# Enter password: Akp#3210

# 3. Run schema script
source ~/webrtc-video-chat/database/schema.sql

# 4. Run stored procedures
source ~/webrtc-video-chat/database/stored_procedures.sql

# 5. Verify
SHOW TABLES;
SHOW PROCEDURE STATUS WHERE Db = 'RTC_Video_Chat_DB';
```

---

# 📅 Day 3: User Authentication API

## Goals
- ✅ Create password hashing utilities
- ✅ Create JWT token utilities
- ✅ Create authentication middleware
- ✅ Create auth controller
- ✅ Create auth routes
- ✅ Test all endpoints

## What We Built

### 1. New Files Created

| File | Purpose | Lines |
|------|---------|-------|
| `app/utils/__init__.py` | Utils package | 14 |
| `app/utils/password.py` | Password hashing with bcrypt | 120 |
| `app/utils/jwt_helper.py` | JWT token generation/validation | 180 |
| `app/middleware/__init__.py` | Middleware package | 12 |
| `app/middleware/auth_middleware.py` | @token_required decorator | 200 |
| `app/controllers/__init__.py` | Controllers package | 15 |
| `app/controllers/auth_controller.py` | Auth business logic | 350 |
| `app/routes/auth_routes.py` | Auth API endpoints | 200 |

### 2. API Endpoints Created

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/auth/register` | POST | Create new account | No |
| `/api/auth/login` | POST | Login and get token | No |
| `/api/auth/me` | GET | Get current user | Yes |
| `/api/auth/logout` | POST | Logout user | Yes |
| `/api/auth/check` | GET | Verify token is valid | Yes |

### 3. Key Concepts Explained

#### Password Hashing with bcrypt

```python
import bcrypt

def hash_password(plain_password):
    """
    Convert password to secure hash.
    
    Example:
        "myPassword" → "$2b$12$LQv3c1yq..."
    """
    password_bytes = plain_password.encode('utf-8')
    salt = bcrypt.gensalt(rounds=12)
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password, hashed_password):
    """
    Check if password matches stored hash.
    Returns True or False.
    """
    return bcrypt.checkpw(
        plain_password.encode('utf-8'),
        hashed_password.encode('utf-8')
    )
```

#### JWT Token Generation

```python
import jwt
from datetime import datetime, timedelta

def generate_token(user_id, username, email):
    """
    Create JWT token with user info.
    Token expires in 7 days.
    """
    payload = {
        'user_id': user_id,
        'username': username,
        'email': email,
        'exp': datetime.utcnow() + timedelta(days=7)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')

def decode_token(token):
    """
    Validate and decode JWT token.
    Returns payload if valid, error if not.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return {'valid': True, 'payload': payload}
    except jwt.ExpiredSignatureError:
        return {'valid': False, 'error': 'Token expired'}
```

#### @token_required Decorator

```python
from functools import wraps
from flask import request, jsonify, g

def token_required(f):
    """
    Decorator to protect routes.
    
    Usage:
        @app.route('/protected')
        @token_required
        def protected_route():
            user = g.current_user
            return jsonify({'hello': user['username']})
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        # Get token from header
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'error': 'No token'}), 401
        
        # Validate token
        result = decode_token(token)
        if not result['valid']:
            return jsonify({'error': result['error']}), 401
        
        # Get user from database
        user = get_user_by_id(result['payload']['user_id'])
        g.current_user = user
        
        return f(*args, **kwargs)
    return decorated
```

### 4. Test Results

| Test | Expected | Result |
|------|----------|--------|
| Register new user | 201 Created | ✅ PASS |
| Register duplicate user | 400 Bad Request | ✅ PASS |
| Register invalid email | 400 Bad Request | ✅ PASS |
| Login with email | 200 OK + token | ✅ PASS |
| Login wrong password | 401 Unauthorized | ✅ PASS |
| Get user with token | 200 OK + user data | ✅ PASS |
| Get user without token | 401 Unauthorized | ✅ PASS |
| Check auth status | 200 OK | ✅ PASS |
| Logout | 200 OK | ✅ PASS |
| Use token after logout | 401 Unauthorized | ✅ PASS |

### 5. How to Test

```bash
# Register
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "john", "email": "john@example.com", "password": "password123"}'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "john@example.com", "password": "password123"}'

# Get Profile (use token from login)
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# Logout
curl -X POST http://localhost:3000/api/auth/logout \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

---

# 📅 Day 4: Authentication UI (Login/Register)

## Goals
- ✅ Create shared CSS stylesheet
- ✅ Create auth JavaScript (API calls, token storage)
- ✅ Create login page
- ✅ Create register page
- ✅ Create dashboard page
- ✅ Update home page with navigation

## What We Built

### 1. New Files Created

| File | Purpose | Lines |
|------|---------|-------|
| `app/static/css/style.css` | Main stylesheet with dark theme | 550+ |
| `app/static/js/auth.js` | Auth API calls, token management | 400+ |
| `app/templates/login.html` | Login form page | 180 |
| `app/templates/register.html` | Registration form page | 220 |
| `app/templates/dashboard.html` | User dashboard after login | 280 |
| `app/templates/index.html` | Updated home page | 180 |

### 2. Pages Created

| Page | URL | Description |
|------|-----|-------------|
| Home | `/` | Landing page with features |
| Login | `/login` | Email/password login form |
| Register | `/register` | Account creation form |
| Dashboard | `/dashboard` | Protected user dashboard |

### 3. Key Features

#### CSS Styling
- Dark theme with CSS variables
- Responsive design (mobile-friendly)
- Animations and transitions
- Form styling with validation states
- Toast notifications
- Modal dialogs

#### JavaScript Auth Module
```javascript
// Token management
Auth.saveAuth(token, user);    // Save to localStorage
Auth.getToken();               // Get stored token
Auth.getUser();                // Get stored user
Auth.clearAuth();              // Clear on logout
Auth.isLoggedIn();             // Check auth state

// API calls
Auth.register(username, email, password);
Auth.login(emailOrUsername, password);
Auth.logout();
Auth.getCurrentUser();
Auth.checkAuth();

// Page protection
Auth.requireAuth();            // Redirect if not logged in
Auth.redirectIfLoggedIn();     // Redirect if already logged in

// UI helpers
Auth.showToast(message, type);
Auth.setButtonLoading(button, loading);
Auth.showFieldError(inputId, message);
```

#### Form Validation
- Client-side validation before API call
- Email format validation
- Username format validation (3-50 chars, alphanumeric)
- Password length validation (min 6 chars)
- Confirm password matching
- Real-time error clearing on input

### 4. User Flow

```
Home Page (/)
    │
    ├── Not Logged In
    │   ├── Click "Get Started" → Register Page
    │   └── Click "Sign In" → Login Page
    │
    └── Logged In
        └── Click "Dashboard" → Dashboard Page

Login Page (/login)
    │
    ├── Enter credentials
    ├── Click "Sign In"
    ├── API validates
    └── Success → Redirect to Dashboard

Register Page (/register)
    │
    ├── Fill form
    ├── Click "Create Account"
    ├── API creates user
    └── Success → Redirect to Dashboard

Dashboard (/dashboard)
    │
    ├── Protected (requires login)
    ├── Shows user profile
    ├── Action cards (Start Call, Join Room, etc.)
    └── Logout button
```

### 5. Test Results

| Test | Result |
|------|--------|
| Home page loads | ✅ PASS |
| Login page loads | ✅ PASS |
| Register page loads | ✅ PASS |
| Dashboard page loads | ✅ PASS |
| CSS file loads | ✅ PASS |
| JS file loads | ✅ PASS |
| Form validation works | ✅ PASS |
| Login flow works | ✅ PASS |
| Register flow works | ✅ PASS |
| Logout works | ✅ PASS |

### 6. How to Test

1. Open browser: http://localhost:3000
2. Click "Get Started" to register
3. Fill in the form and submit
4. You'll be redirected to dashboard
5. Click "Logout" to test logout
6. Try logging in with your credentials

---

## 🔜 Day 5 Preview: Signaling Server + Room Management

### What We'll Build
1. Socket.IO event handlers
2. Room creation API
3. Room joining logic
4. User presence tracking
5. Room page UI

---

## Python Learning Notes

### Virtual Environment
```bash
# A virtual environment isolates project dependencies
# Each project has its own copy of packages

# Create virtual environment
python3 -m venv venv

# Activate it (Mac/Linux)
source venv/bin/activate

# Activate it (Windows)
venv\Scripts\activate

# Install packages
pip install -r requirements.txt

# When done
deactivate
```

### Flask Basics
```python
# Flask uses decorators to map URLs to functions

from flask import Flask, jsonify

app = Flask(__name__)

# Route decorator - maps URL to function
@app.route('/hello')
def hello():
    return 'Hello World!'

# JSON response
@app.route('/api/data')
def get_data():
    return jsonify({'message': 'Hello', 'status': 'OK'})

# Route with variable
@app.route('/user/<user_id>')
def get_user(user_id):
    return f'User ID: {user_id}'

# POST request
@app.route('/api/submit', methods=['POST'])
def submit():
    data = request.get_json()
    return jsonify({'received': data})
```

### Flask-SocketIO Basics
```python
# Socket.IO enables real-time bidirectional communication

from flask_socketio import SocketIO, emit

socketio = SocketIO(app)

# When a client connects
@socketio.on('connect')
def handle_connect():
    print('Client connected!')

# When client sends a message
@socketio.on('message')
def handle_message(data):
    print(f'Message: {data}')
    # Send to all clients
    emit('message', data, broadcast=True)

# Custom events
@socketio.on('join_room')
def handle_join(room_code):
    join_room(room_code)
    emit('user_joined', {'room': room_code}, room=room_code)
```

---

## Git Workflow

Each day's development goes on its own branch:

```bash
# Create Day-1 branch
git checkout -b Day-1-Python

# After completing Day 1
git add .
git commit -m "Day 1: Python environment setup"
git push -u origin Day-1-Python

# For Day 2
git checkout main
git checkout -b Day-2-Python
# ... do Day 2 work ...
git add .
git commit -m "Day 2: Database schema and stored procedures"
git push -u origin Day-2-Python
```

---

---

# 📅 Day 5: Signaling Server + Room Management

## Goals
- ✅ Create Socket.IO event handlers for signaling
- ✅ Implement room creation and joining
- ✅ Build room management API
- ✅ Create video room UI
- ✅ Implement WebRTC JavaScript manager
- ✅ Test room functionality

## What We Built

### 1. Socket.IO Event Handlers (`app/socket/events.py`)

**WHAT IS SOCKET.IO?**

Socket.IO enables real-time, bidirectional communication between browsers and servers. Unlike regular HTTP (request → response), Socket.IO keeps a persistent connection open.

```
HTTP Communication:
    Client → Request → Server → Response → Client
    (Connection closes after each request)

Socket.IO Communication:
    Client ←→ Server
    (Connection stays open, both can send anytime)
```

**WHY DO WE NEED IT FOR WEBRTC?**

WebRTC needs a "signaling server" to exchange connection information BEFORE peers can connect directly:

1. User A wants to call User B
2. User A sends "offer" to signaling server
3. Server forwards "offer" to User B
4. User B sends "answer" back through server
5. Both exchange ICE candidates through server
6. Once they have enough info, they connect directly (P2P)

After step 6, video/audio flows directly between browsers, NOT through our server!

**SOCKET EVENTS WE IMPLEMENTED:**

| Event | Direction | Purpose |
|-------|-----------|---------|
| `connect` | Client → Server | Client connected |
| `disconnect` | Client → Server | Client disconnected |
| `authenticate` | Client → Server | Verify JWT token |
| `create_room` | Client → Server | Create new room |
| `join_room` | Client → Server | Join existing room |
| `leave_room` | Client → Server | Leave room |
| `offer` | Client → Server → Client | WebRTC offer (SDP) |
| `answer` | Client → Server → Client | WebRTC answer (SDP) |
| `ice_candidate` | Client → Server → Client | ICE candidate |
| `toggle_audio` | Client → Server → Room | Mic on/off |
| `toggle_video` | Client → Server → Room | Camera on/off |
| `chat_message` | Client → Server → Room | Text chat |

### 2. Room Controller (`app/controllers/room_controller.py`)

Handles room management through REST API:

```python
class RoomController:
    @staticmethod
    def generate_room_code():
        """Generate unique code like ABC-123-XYZ"""
        
    @staticmethod
    def create_room(user_id, data):
        """Create new video chat room"""
        
    @staticmethod
    def get_room(room_code):
        """Get room information"""
        
    @staticmethod
    def get_room_participants(room_code):
        """Get list of participants"""
```

### 3. Room API Routes (`app/routes/room_routes.py`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/rooms` | Create new room |
| GET | `/api/rooms/<code>` | Get room info |
| GET | `/api/rooms/<code>/participants` | Get participants |
| POST | `/api/rooms/<code>/verify-password` | Verify room password |

### 4. WebRTC Manager (`app/static/js/webrtc.js`)

**WHAT IS WEBRTC?**

WebRTC (Web Real-Time Communication) enables peer-to-peer video/audio communication directly between browsers.

**KEY CONCEPTS:**

1. **Peer Connection (RTCPeerConnection)**
   - The main WebRTC object
   - Handles the actual media connection between two peers
   - Each connection to another user needs one

2. **Media Stream (MediaStream)**
   - Contains video and/or audio tracks
   - Local stream: Your camera/mic
   - Remote stream: Other person's camera/mic

3. **SDP (Session Description Protocol)**
   - Describes what media you can send/receive
   - Exchanged as "offer" and "answer"

4. **ICE (Interactive Connectivity Establishment)**
   - Finds the best path to connect two peers
   - Uses STUN servers to find public IPs

**CONNECTION FLOW:**

```
1. User A creates an "offer" (SDP)
   ↓
2. User A sends offer to User B via signaling server
   ↓
3. User B receives offer, creates "answer" (SDP)
   ↓
4. User B sends answer to User A
   ↓
5. Both exchange ICE candidates
   ↓
6. Connection established! Video flows directly P2P
```

**WebRTCManager Class Methods:**

```javascript
class WebRTCManager {
    // Get local camera/mic
    async getLocalMedia(constraints)
    
    // Toggle audio/video
    toggleAudio()
    toggleVideo()
    
    // Peer connections
    createPeerConnection(socketId)
    async createOffer(socketId)
    async createAnswer(socketId, offer)
    async handleAnswer(socketId, answer)
    async addIceCandidate(socketId, candidate)
    
    // Screen sharing
    async startScreenShare()
    async stopScreenShare()
    
    // Cleanup
    closePeerConnection(socketId)
    closeAllConnections()
}
```

### 5. Room Page UI (`app/templates/room.html`)

**STRUCTURE:**

```
┌─────────────────────────────────────────────────┐
│  HEADER: Room Name | Room Code | Participants   │
├─────────────────────────────────────────────────┤
│                                          │ CHAT │
│         VIDEO GRID                       │      │
│  ┌─────────────┐  ┌─────────────┐       │ msg  │
│  │    YOU      │  │   PEER 1    │       │ msg  │
│  │   (local)   │  │  (remote)   │       │ msg  │
│  └─────────────┘  └─────────────┘       │      │
│                                          │[___] │
├─────────────────────────────────────────────────┤
│  CONTROLS: 🎤 Mic | 📹 Cam | 🖥️ Screen | 📞 Leave │
└─────────────────────────────────────────────────┘
```

### 6. Room Controller JS (`app/static/js/room.js`)

Connects everything together:

1. Page loads → Connect to Socket.IO
2. Authenticate with JWT token
3. Join the room
4. When another user joins → Create WebRTC connection
5. Exchange offers/answers/ICE candidates
6. Video streams flow directly between browsers

## Files Created/Modified

| File | Type | Purpose |
|------|------|---------|
| `app/socket/__init__.py` | New | Socket package init |
| `app/socket/events.py` | New | Socket.IO event handlers |
| `app/controllers/room_controller.py` | New | Room business logic |
| `app/routes/room_routes.py` | New | Room API endpoints |
| `app/templates/room.html` | New | Video room page |
| `app/static/css/room.css` | New | Room page styles |
| `app/static/js/webrtc.js` | New | WebRTC manager |
| `app/static/js/room.js` | New | Room page controller |
| `app/__init__.py` | Modified | Register room routes & socket events |
| `app/routes/__init__.py` | Modified | Add room blueprint |

## API Test Results

### Create Room
```bash
POST /api/rooms
Authorization: Bearer <token>
Body: {"room_name": "Test Meeting Room"}

Response:
{
  "success": true,
  "message": "Room created successfully",
  "data": {
    "room_id": 2,
    "room_code": "FTD-F1L-B0E",
    "room_name": "Test Meeting Room",
    "max_participants": 10,
    "is_private": false,
    "join_url": "/room/FTD-F1L-B0E"
  }
}
```

### Get Room Info
```bash
GET /api/rooms/FTD-F1L-B0E

Response:
{
  "success": true,
  "message": "Room found",
  "data": {
    "room_id": 2,
    "room_code": "FTD-F1L-B0E",
    "room_name": "Test Meeting Room",
    "host_id": 2,
    "host_name": "Test User 5",
    "max_participants": 10,
    "current_participants": 0,
    "is_private": false,
    "room_status": "waiting"
  }
}
```

## Key Learnings

### 1. Socket.IO Rooms
```python
# Join a room (group of sockets)
join_room(room_code)

# Send to everyone in room
emit('event', data, room=room_code)

# Send to everyone EXCEPT sender
emit('event', data, room=room_code, include_self=False)

# Leave room
leave_room(room_code)
```

### 2. WebRTC ICE Servers
```javascript
// STUN servers help discover public IP
const iceServers = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
    ]
};
```

### 3. Media Constraints
```javascript
const constraints = {
    video: {
        width: { ideal: 1280 },
        height: { ideal: 720 },
        facingMode: 'user'  // Front camera
    },
    audio: {
        echoCancellation: true,
        noiseSuppression: true
    }
};
```

---

*Last updated: Day 5 - Signaling Server + Room Management*
