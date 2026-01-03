# 📖 WebRTC Video-Chat Development Log

This document tracks the complete development progress of the WebRTC Video-Chat application, with detailed explanations of every step for learning purposes.

---

## 📋 Project Information

| Field | Value |
|-------|-------|
| **Project Name** | WebRTC Video-Chat |
| **Database Name** | RTC_Video_Chat_DB |
| **GitHub Repository** | https://github.com/Rahulrkp321/webrtc-video-chat.git |
| **Developer** | Rahulrkp321 |
| **Start Date** | January 2, 2026 |
| **Platform** | MacBook Air (macOS 15.4.1 Sequoia) |

---

## 📊 Technology Stack

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| Runtime | Node.js | 20.19.5 | JavaScript runtime for server |
| Web Framework | Express | 5.2.1 | Handle HTTP requests |
| Real-time | Socket.IO | 4.8.3 | WebSocket communication for signaling |
| Database | MySQL | 9.5.0 | Store users, rooms, calls, contacts |
| Auth | JWT (jsonwebtoken) | 9.0.3 | User authentication tokens |
| Security | bcryptjs | 3.0.3 | Password hashing |
| Utilities | uuid | 13.0.0 | Generate unique room codes |

---

# 📆 DAY 1: Environment Setup & Project Initialization

**Date:** January 2, 2026  
**Duration:** ~2 hours  
**Status:** ✅ COMPLETED

---

## 🎯 Day 1 Objectives

1. ✅ Set up development environment
2. ✅ Create project structure
3. ✅ Install dependencies
4. ✅ Create configuration files
5. ✅ Build basic Express server
6. ✅ Create landing page
7. ✅ Initialize Git repository
8. ⏳ Push to GitHub (pending authentication)

---

## 📝 Step-by-Step Progress

### Step 1.1: Verify System Requirements

**Command Used:**
```bash
sw_vers                 # Check macOS version
brew --version          # Check Homebrew
git --version           # Check Git
node --version          # Check Node.js
mysql --version         # Check MySQL
```

**Results:**
```
macOS: 15.4.1 (Sequoia)
Homebrew: 4.6.17
Git: 2.39.5
Node.js: 20.19.5
MySQL: 9.4.0 (client only - server installed later)
```

**What We Learned:**
- `sw_vers` - Shows macOS version information
- `brew` - Homebrew is a package manager for macOS (like an app store for command-line tools)
- `node` - Node.js lets us run JavaScript outside the browser
- `mysql` - Database system for storing data

---

### Step 1.2: Create Project Directory

**Command Used:**
```bash
cd ~                                    # Go to home directory
mkdir -p webrtc-video-chat             # Create project folder
cd webrtc-video-chat                   # Enter the folder
```

**What We Learned:**
- `~` represents your home folder (`/Users/rahulpathak`)
- `mkdir -p` creates directories, `-p` means "create parent directories if needed"
- `cd` means "change directory" - navigates to a folder

---

### Step 1.3: Create Folder Structure

**Command Used:**
```bash
mkdir -p public/css public/js server/config server/routes server/controllers server/models server/middleware server/socket database logs
```

**Folder Structure Created:**
```
webrtc-video-chat/
├── public/              ← Frontend files (what users see)
│   ├── css/            ← Stylesheets (colors, fonts, layout)
│   └── js/             ← Client-side JavaScript
├── server/             ← Backend code (server logic)
│   ├── config/         ← Configuration files
│   ├── routes/         ← API endpoint definitions
│   ├── controllers/    ← Business logic handlers
│   ├── models/         ← Database operations
│   ├── middleware/     ← Request preprocessing
│   └── socket/         ← Real-time Socket.IO handlers
├── database/           ← SQL scripts
└── logs/               ← Application logs
```

**What We Learned:**
- Separation of concerns: Frontend (public) vs Backend (server)
- MVC pattern: Models (data), Views (public), Controllers (logic)
- Each folder has a specific purpose for organized code

---

### Step 1.4: Initialize Node.js Project

**Command Used:**
```bash
npm init -y
```

**What This Creates:**
A `package.json` file - the "ID card" of our project containing:
- Project name and version
- Entry point (main file)
- Scripts (commands to run)
- Dependencies (libraries we use)

**package.json Created:**
```json
{
  "name": "webrtc-video-chat",
  "version": "1.0.0",
  "description": "A real-time video chat application built with WebRTC, Node.js, and MySQL",
  "main": "server/index.js",
  "scripts": {
    "start": "node server/index.js",
    "dev": "node server/index.js"
  },
  "author": "Rahulrkp321",
  "license": "MIT"
}
```

**What We Learned:**
- `npm` = Node Package Manager (downloads and manages libraries)
- `npm init -y` creates package.json with default values
- `scripts` define commands like `npm start`

---

### Step 1.5: Install Dependencies

**Command Used:**
```bash
npm install express socket.io mysql2 dotenv bcryptjs jsonwebtoken cors uuid
```

**Libraries Installed (113 packages total):**

| Library | Purpose | Analogy |
|---------|---------|---------|
| **express** | Web server framework | Foundation of a house |
| **socket.io** | Real-time communication | Walkie-talkie system |
| **mysql2** | MySQL database driver | Translator for database |
| **dotenv** | Environment variables | Secure vault for secrets |
| **bcryptjs** | Password encryption | Scrambling machine |
| **jsonwebtoken** | Login tokens | VIP access card |
| **cors** | Cross-origin requests | Border pass |
| **uuid** | Unique ID generator | Unique stamp maker |

**What We Learned:**
- `npm install` downloads packages from npmjs.com
- Creates `node_modules/` folder with all library code
- Creates `package-lock.json` with exact versions

---

### Step 1.6: Create Environment Configuration

**File Created:** `.env`

```env
# Server Configuration
NODE_ENV=development
PORT=3000

# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=Akp#3210
DB_NAME=RTC_Video_Chat_DB

# JWT Configuration
JWT_SECRET=webrtc-video-chat-super-secret-key-change-in-production-2024
JWT_EXPIRES_IN=7d

# Application Settings
MAX_PARTICIPANTS_PER_ROOM=10
```

**What We Learned:**
- Environment variables store configuration outside code
- Keeps secrets (passwords) out of source code
- Different values for development vs production
- `.env` file is NEVER uploaded to GitHub (security!)

---

### Step 1.7: Create .gitignore

**File Created:** `.gitignore`

```gitignore
node_modules/          # Downloaded libraries (large!)
.env                   # Secret configuration
logs/                  # Log files
*.log                  # Any log file
.DS_Store              # macOS system files
```

**What We Learned:**
- `.gitignore` tells Git which files to ignore
- `node_modules/` is huge and can be recreated with `npm install`
- Never commit passwords or secrets to Git

---

### Step 1.8: Create Database Configuration

**File Created:** `server/config/database.js`

**Key Concepts Explained:**

```javascript
// Connection Pool - What is it?
// Instead of creating a new database connection for each request (slow),
// we create a "pool" of connections that stay open and get reused (fast).
// Like a taxi stand - taxis wait there instead of being called each time.

const pool = mysql.createPool({
    host: 'localhost',        // Where database is (your computer)
    port: 3306,               // MySQL's "door number"
    user: 'root',             // MySQL username
    password: 'Akp#3210',     // MySQL password
    database: 'RTC_Video_Chat_DB',
    connectionLimit: 10       // Max 10 simultaneous connections
});
```

**What We Learned:**
- Connection pooling improves performance
- `require('dotenv').config()` loads `.env` file
- `async/await` for cleaner asynchronous code
- Error handling with try/catch blocks

---

### Step 1.9: Create Main Server File

**File Created:** `server/index.js`

**Key Components:**

```javascript
// 1. EXPRESS - Web Server Framework
const express = require('express');
const app = express();

// 2. HTTP SERVER - Required for Socket.IO
const http = require('http');
const server = http.createServer(app);

// 3. SOCKET.IO - Real-time Communication
const { Server } = require('socket.io');
const io = new Server(server);

// 4. MIDDLEWARE - Code that runs before routes
app.use(cors());                    // Allow cross-origin requests
app.use(express.json());            // Parse JSON request bodies
app.use(express.static('public'));  // Serve static files

// 5. ROUTES - URL patterns
app.get('/api/health', (req, res) => {
    res.json({ status: 'OK' });
});

// 6. START SERVER
server.listen(3000, () => {
    console.log('Server running on port 3000');
});
```

**What We Learned:**
- Express simplifies creating web servers
- Middleware processes requests before they reach routes
- Routes map URLs to functions
- Socket.IO needs an HTTP server to attach to

---

### Step 1.10: Create Landing Page

**File Created:** `public/index.html`

**Key Features:**
- Responsive design (works on mobile and desktop)
- Dark theme with gradient background
- CSS animations (pulse, fade-in)
- JavaScript to check server health
- Status indicator with real-time updates

**CSS Concepts Used:**
```css
/* CSS Variables - Define once, use everywhere */
:root {
    --primary-color: #6366f1;
    --background-dark: #0f172a;
}

/* Flexbox - Easy centering */
body {
    display: flex;
    justify-content: center;
    align-items: center;
}

/* Animations */
@keyframes pulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.1); }
}
```

**What We Learned:**
- CSS variables for consistent theming
- Flexbox for layout
- Keyframe animations for effects
- Fetch API for HTTP requests

---

### Step 1.11: Install MySQL Server

**Commands Used:**
```bash
brew install mysql           # Install MySQL server
brew services start mysql    # Start MySQL as background service
```

**What We Learned:**
- `mysql-client` (already installed) is for connecting TO a database
- `mysql` (server) is the actual database engine
- `brew services` manages background services on macOS

---

### Step 1.12: Initialize Git Repository

**Commands Used:**
```bash
git init                     # Initialize Git repository
git add .                    # Stage all files
git commit -m "Day 1: Initial project setup"  # Create commit
git remote add origin https://github.com/Rahulrkp321/webrtc-video-chat.git
```

**Commit Message:**
```
Day 1: Initial project setup

✅ Project Structure
✅ Dependencies Installed
✅ Configuration Files
✅ Server Implementation
✅ Landing Page
```

**What We Learned:**
- `git init` creates a new repository
- `git add .` stages all files for commit
- `git commit` saves a snapshot of your code
- `git remote add` connects local repo to GitHub

---

## 📊 Day 1 Test Results

| Test ID | Test Case | Result |
|---------|-----------|--------|
| T1.1 | Node.js installed | ✅ PASS (v20.19.5) |
| T1.2 | npm working | ✅ PASS |
| T1.3 | Dependencies installed | ✅ PASS (113 packages) |
| T1.4 | MySQL server running | ✅ PASS |
| T1.5 | MySQL connection | ✅ PASS |
| T1.6 | Server starts | ✅ PASS |
| T1.7 | Health endpoint | ✅ PASS |
| T1.8 | Landing page loads | ✅ PASS |
| T1.9 | Git initialized | ✅ PASS |
| T1.10 | Push to GitHub | ⏳ PENDING (needs token) |

---

## 📁 Files Created on Day 1

| File | Lines | Purpose |
|------|-------|---------|
| `package.json` | 23 | Project configuration |
| `package-lock.json` | ~2000 | Exact dependency versions |
| `.env` | 15 | Environment variables |
| `.env.example` | 14 | Template for others |
| `.gitignore` | 30 | Files to ignore |
| `server/index.js` | 240 | Main server file |
| `server/config/database.js` | 95 | Database connection |
| `public/index.html` | 350 | Landing page |

**Total:** ~2,800 lines of code/configuration

---

## 🚀 Server Running Successfully!

**URL:** http://localhost:3000

**Screenshot Verified:**
- ✅ Server Online indicator (green)
- ✅ Status: OK
- ✅ Uptime displayed
- ✅ Day 1 Setup Complete message

---

## 🔜 Coming Up: Day 2

**Day 2: Database Schema & User Stored Procedures**

What we'll build:
1. Create the database `RTC_Video_Chat_DB`
2. Create all 6 tables with audit fields
3. Create user-related stored procedures (dt_vc_* prefix)
4. Test database operations

---

## 📚 Glossary of Terms

| Term | Simple Explanation |
|------|-------------------|
| **Node.js** | JavaScript runtime that runs on your computer (not in browser) |
| **npm** | Tool to download and manage JavaScript libraries |
| **Express** | Library that makes creating web servers easy |
| **Socket.IO** | Library for real-time, two-way communication |
| **MySQL** | Database system that stores data in tables |
| **API** | Way for programs to talk to each other |
| **Endpoint** | A URL that does something (like `/api/health`) |
| **Middleware** | Code that runs before your main code |
| **Git** | Version control - tracks changes to your code |
| **Repository** | A folder tracked by Git |
| **Commit** | A saved snapshot of your code |

---

*This log will be updated daily as development progresses.*

