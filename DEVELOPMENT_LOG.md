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
| Day 4 | Authentication UI (Login/Register) | 🔜 Next |
| Day 5 | Signaling Server + Room Management | ⏳ Pending |
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

## 🔜 Day 4 Preview: Authentication UI

### What We'll Build
1. Login page with form
2. Register page with form
3. Dashboard (after login)
4. Navigation with auth state
5. Token storage in localStorage
6. Protected page redirects

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

*Last updated: Day 3 - User Authentication API*
