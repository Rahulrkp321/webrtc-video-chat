# 🎥 WebRTC Video-Chat

A real-time video calling application built with Python/Flask backend and WebRTC for peer-to-peer video communication.

## 🌟 Features

### ✅ Currently Working
- **User Authentication:** Secure login/registration with JWT tokens
- **Room Management:** Create and join video rooms with unique codes
- **WebRTC Video Calls:** Peer-to-peer video communication
- **Multiple Participants:** Support for up to 10 users per room
- **Media Controls:**
  - 🎤 Toggle microphone (mute/unmute)
  - 📹 Toggle camera (on/off)
  - 🖥️ Screen sharing
- **Text Chat:** Real-time messaging in rooms
- **Device Settings:** Select camera/microphone
- **Responsive UI:** Modern dark theme design

### 🚧 Coming Soon
- Contact list management
- Call history tracking
- Enhanced group call features
- Recording capabilities

## 🏗️ Technology Stack

| Component | Technology |
|-----------|------------|
| **Backend** | Python 3.13 + Flask 3.1.0 |
| **Real-time** | Flask-SocketIO + Socket.IO |
| **Database** | MySQL 8.0+ |
| **WebRTC** | Browser WebRTC APIs |
| **Authentication** | JWT (PyJWT) + bcrypt |
| **Frontend** | HTML/CSS/JavaScript |

## 📋 Prerequisites

- Python 3.13+
- MySQL 8.0+
- Modern web browser (Chrome, Firefox, Safari, Edge)
- Camera and microphone (for video calls)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Rahulrkp321/webrtc-video-chat.git
cd webrtc-video-chat
```

### 2. Set Up Python Virtual Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Mac/Linux
# OR
venv\Scripts\activate  # On Windows

# Install dependencies
pip install -r requirements.txt
```

### 3. Set Up Database

```bash
# Start MySQL
brew services start mysql  # On Mac
# OR
sudo systemctl start mysql  # On Linux

# Connect to MySQL
mysql -u root -p

# Run database setup scripts
source database/schema.sql
source database/stored_procedures.sql
```

### 4. Configure Environment Variables

Create a `.env` file in the project root:

```env
# Server Configuration
FLASK_ENV=development
SECRET_KEY=your-secret-key-here-change-this

# Database Configuration
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your-mysql-password
DB_NAME=RTC_Video_Chat_DB
DB_PORT=3306

# JWT Configuration
JWT_SECRET_KEY=your-jwt-secret-key-here-change-this
JWT_EXPIRATION_DAYS=7
```

### 5. Start the Server

```bash
# Using the venv Python directly
/path/to/your/webrtc-video-chat/venv/bin/python run.py

# OR if venv is activated
python run.py
```

Server will start on: **http://localhost:3000**

## 📖 How to Use

### Creating Your First Video Room

1. **Register an Account**
   - Navigate to http://localhost:3000
   - Click "Get Started" or "Sign Up"
   - Fill in your details (username, email, password)
   - Submit the form

2. **Login**
   - Go to http://localhost:3000/login
   - Enter your credentials
   - Click "Sign In"

3. **Create a Room**
   - Click "Dashboard" after logging in
   - Click "Start New Call"
   - Your room will be created with a unique code (e.g., ABC-123-XYZ)
   - Allow camera/microphone access when prompted

4. **Invite Others**
   - Share the room code with others
   - They can join by clicking "Join Room" on their dashboard
   - Enter the room code and click "Join"

### Testing with Multiple Users

**Option 1: Different Browsers**
- User A: Use Chrome
- User B: Use Firefox

**Option 2: Incognito Mode**
- User A: Regular browser window
- User B: Incognito/Private window

**Option 3: Different Devices**
- User A: Your computer
- User B: Your phone or another computer

## 🎮 Controls

While in a video call:

| Button | Action |
|--------|--------|
| 🎤 **Mic** | Toggle microphone on/off |
| 📹 **Camera** | Toggle camera on/off |
| 🖥️ **Screen** | Share your screen |
| 💬 **Chat** | Open text chat panel |
| ⚙️ **Settings** | Change camera/microphone |
| 📞 **Leave** | Exit the room |

## 📁 Project Structure

```
webrtc-video-chat/
├── app/                          # Main application package
│   ├── __init__.py              # Flask app factory
│   ├── config/                  # Configuration
│   │   └── database.py          # MySQL connection
│   ├── controllers/             # Business logic
│   │   ├── auth_controller.py
│   │   └── room_controller.py
│   ├── middleware/              # Authentication middleware
│   │   └── auth_middleware.py
│   ├── routes/                  # Route definitions
│   │   ├── main_routes.py       # Page routes
│   │   ├── auth_routes.py       # Auth API
│   │   └── room_routes.py       # Room API
│   ├── socket/                  # Socket.IO handlers
│   │   └── events.py
│   ├── utils/                   # Utilities
│   │   ├── jwt_helper.py
│   │   └── password.py
│   ├── templates/               # HTML templates
│   │   ├── index.html
│   │   ├── login.html
│   │   ├── register.html
│   │   ├── dashboard.html
│   │   └── room.html
│   └── static/                  # Static files
│       ├── css/
│       │   ├── style.css
│       │   └── room.css
│       └── js/
│           ├── auth.js
│           ├── webrtc.js
│           └── room.js
├── database/                    # SQL files
│   ├── schema.sql               # Table definitions
│   └── stored_procedures.sql    # All stored procedures
├── docs/                        # Documentation
│   └── PROGRESS_REPORT.md
├── venv/                        # Virtual environment
├── .env                         # Environment variables (create this)
├── .env.example                 # Example env file
├── requirements.txt             # Python dependencies
├── run.py                       # Application entry point
├── DEVELOPMENT_LOG.md           # Detailed development notes
└── README.md                    # This file
```

## 🔌 API Endpoints

### Authentication

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/auth/register` | POST | Register new user | No |
| `/api/auth/login` | POST | Login user | No |
| `/api/auth/me` | GET | Get current user | Yes |
| `/api/auth/logout` | POST | Logout user | Yes |

### Rooms

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/rooms` | POST | Create new room | Yes |
| `/api/rooms/<code>` | GET | Get room info | No |
| `/api/rooms/<code>/participants` | GET | Get participants | No |

## 🔧 Configuration

### Change Maximum Participants

Edit `app/controllers/room_controller.py`:

```python
# Default is 10
max_participants = data.get('max_participants', 10)
```

### Change JWT Expiration

Edit `.env`:

```env
JWT_EXPIRATION_DAYS=7  # Change to desired days
```

### Add TURN Servers

For better connectivity across NATs, add TURN servers in `app/static/js/webrtc.js`:

```javascript
this.iceServers = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        {
            urls: 'turn:your-turn-server.com:3478',
            username: 'username',
            credential: 'password'
        }
    ]
};
```

## 🐛 Troubleshooting

### Camera/Microphone Not Working

1. **Check browser permissions:**
   - Chrome: Settings → Privacy and security → Site settings → Camera/Microphone
   - Firefox: Settings → Privacy & Security → Permissions

2. **Use HTTPS:** WebRTC requires HTTPS in production. For local development, `localhost` works.

3. **Check device availability:**
   - Make sure no other app is using your camera/microphone
   - Try restarting your browser

### Connection Issues

1. **Check STUN/TURN servers:** Some networks block WebRTC. You may need TURN servers.

2. **Firewall/Antivirus:** Temporarily disable to test

3. **Browser console:** Check for errors in browser developer tools (F12)

### Server Not Starting

1. **Check port 3000:** Make sure nothing else is using port 3000
   ```bash
   lsof -ti:3000  # On Mac/Linux
   ```

2. **Check MySQL:** Ensure MySQL is running and credentials are correct

3. **Check Python version:** Must be Python 3.13+
   ```bash
   python --version
   ```

## 📊 Current Progress

**67% Complete (8/12 Days)**

- ✅ Environment Setup
- ✅ Database Schema
- ✅ User Authentication
- ✅ Authentication UI
- ✅ Signaling Server
- ✅ WebRTC Implementation
- ✅ Complete Video Call Flow
- ✅ Call Controls + Features
- ⏳ Contact List + Call History
- ⏳ Group Call Enhancements
- ⏳ Polish + Testing
- ⏳ Documentation + Deployment

## 🤝 Contributing

This is a learning project. Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## 📝 License

This project is open source and available for educational purposes.

## 👤 Author

**Rahul Pathak**
- GitHub: [@Rahulrkp321](https://github.com/Rahulrkp321)

## 🙏 Acknowledgments

- Google for free STUN servers
- Flask-SocketIO team
- WebRTC community

---

**Last Updated:** February 19, 2026

**Status:** ✅ Core functionality complete and working!

For detailed development notes, see [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md)

