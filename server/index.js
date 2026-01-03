/**
 * ============================================
 * MAIN SERVER FILE - WebRTC Video-Chat
 * ============================================
 * This is the entry point of our application.
 * When you run "npm start", this file executes.
 * 
 * WHAT THIS FILE DOES:
 * 1. Creates an Express web server
 * 2. Sets up Socket.IO for real-time communication
 * 3. Connects to the database
 * 4. Defines API routes
 * 5. Serves static files (HTML, CSS, JS)
 * 6. Starts listening for requests
 * ============================================
 */

// ============================================
// STEP 1: IMPORT REQUIRED MODULES
// ============================================

/**
 * express - Web server framework
 * Think of it as the foundation of our server
 */
const express = require('express');

/**
 * http - Node.js built-in module to create HTTP server
 * We need this because Socket.IO needs an HTTP server
 */
const http = require('http');

/**
 * socket.io - Real-time bidirectional communication
 * This is how we'll handle WebRTC signaling
 */
const { Server } = require('socket.io');

/**
 * path - Node.js built-in module for file paths
 * Helps us navigate file system regardless of OS
 */
const path = require('path');

/**
 * cors - Cross-Origin Resource Sharing
 * Allows our frontend to talk to our backend
 */
const cors = require('cors');

/**
 * dotenv - Load environment variables from .env file
 * Must be called early to make variables available
 */
require('dotenv').config();

/**
 * Database connection (we created this in previous step)
 */
const { testConnection } = require('./config/database');


// ============================================
// STEP 2: CREATE EXPRESS APP AND HTTP SERVER
// ============================================

/**
 * Create Express application
 * This is our main app that handles all HTTP requests
 */
const app = express();

/**
 * Create HTTP server with Express app
 * Socket.IO needs this to work alongside Express
 */
const server = http.createServer(app);

/**
 * Create Socket.IO server attached to HTTP server
 * 
 * cors settings allow connections from any origin during development
 * In production, you'd limit this to your actual domain
 */
const io = new Server(server, {
    cors: {
        origin: '*',  // Allow all origins (development only)
        methods: ['GET', 'POST']
    }
});

/**
 * Get port from environment or use 3000 as default
 */
const PORT = process.env.PORT || 3000;


// ============================================
// STEP 3: CONFIGURE MIDDLEWARE
// ============================================

/**
 * WHAT IS MIDDLEWARE?
 * Middleware is code that runs BEFORE your route handlers.
 * Think of it like security checkpoints at an airport.
 * Every request passes through these checkpoints.
 */

/**
 * cors() - Allow cross-origin requests
 * Without this, browsers would block requests from frontend
 */
app.use(cors());

/**
 * express.json() - Parse JSON request bodies
 * When frontend sends JSON data, this converts it to JavaScript object
 * 
 * Example:
 * Frontend sends: {"username": "john", "password": "123"}
 * We receive: req.body = { username: "john", password: "123" }
 */
app.use(express.json());

/**
 * express.urlencoded() - Parse URL-encoded bodies
 * When HTML forms submit data, this parses it
 */
app.use(express.urlencoded({ extended: true }));

/**
 * express.static() - Serve static files
 * This makes our public folder accessible via URLs
 * 
 * Example:
 * File: public/css/styles.css
 * URL: http://localhost:3000/css/styles.css
 */
app.use(express.static(path.join(__dirname, '../public')));


// ============================================
// STEP 4: DEFINE BASIC ROUTES
// ============================================

/**
 * WHAT IS A ROUTE?
 * A route is a URL pattern that triggers specific code.
 * 
 * Example:
 * GET /api/health → returns server status
 * POST /api/auth/login → handles login
 */

/**
 * Health Check Endpoint
 * 
 * URL: GET /api/health
 * Purpose: Check if server is running
 * 
 * This is useful for:
 * - Monitoring services
 * - Load balancers
 * - Quick "is it working?" checks
 */
app.get('/api/health', (req, res) => {
    res.json({
        status: 'OK',
        message: 'WebRTC Video-Chat Server is running!',
        timestamp: new Date().toISOString(),
        uptime: process.uptime() + ' seconds'
    });
});

/**
 * Root Route - Serve Homepage
 * 
 * URL: GET /
 * Purpose: Show the main page
 */
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '../public/index.html'));
});

/**
 * API Info Route
 * 
 * URL: GET /api
 * Purpose: Show available API endpoints
 */
app.get('/api', (req, res) => {
    res.json({
        name: 'WebRTC Video-Chat API',
        version: '1.0.0',
        endpoints: {
            health: 'GET /api/health',
            auth: {
                register: 'POST /api/auth/register',
                login: 'POST /api/auth/login',
                me: 'GET /api/auth/me',
                logout: 'POST /api/auth/logout'
            },
            rooms: {
                create: 'POST /api/rooms',
                list: 'GET /api/rooms',
                get: 'GET /api/rooms/:code'
            },
            contacts: {
                list: 'GET /api/contacts',
                add: 'POST /api/contacts',
                remove: 'DELETE /api/contacts/:id'
            },
            calls: {
                history: 'GET /api/calls'
            }
        }
    });
});


// ============================================
// STEP 5: SOCKET.IO CONNECTION HANDLING
// ============================================

/**
 * WHAT IS SOCKET.IO?
 * Socket.IO enables real-time, bidirectional communication.
 * 
 * Normal HTTP is like sending letters:
 * - Client sends request
 * - Server sends response
 * - Connection closes
 * 
 * Socket.IO is like a phone call:
 * - Connection stays open
 * - Both sides can talk anytime
 * - Instant communication
 * 
 * We need this for:
 * - WebRTC signaling (connecting peers)
 * - Real-time notifications
 * - Online/offline status
 */

io.on('connection', (socket) => {
    console.log(`🔌 New connection: ${socket.id}`);
    
    /**
     * Handle disconnection
     */
    socket.on('disconnect', () => {
        console.log(`🔌 Disconnected: ${socket.id}`);
    });
    
    /**
     * Simple test event
     * Client can emit 'ping', server responds with 'pong'
     */
    socket.on('ping', () => {
        socket.emit('pong', { message: 'Pong!', time: new Date().toISOString() });
    });
});


// ============================================
// STEP 6: ERROR HANDLING
// ============================================

/**
 * 404 Handler - Route not found
 * 
 * This catches any request that doesn't match our routes
 */
app.use((req, res, next) => {
    // Check if it's an API request
    if (req.path.startsWith('/api')) {
        return res.status(404).json({
            success: false,
            message: 'API endpoint not found',
            path: req.path
        });
    }
    // For non-API requests, send to index.html (for SPA routing)
    res.sendFile(path.join(__dirname, '../public/index.html'));
});

/**
 * Global Error Handler
 * 
 * Catches any errors thrown in the application
 */
app.use((error, req, res, next) => {
    console.error('❌ Server Error:', error.message);
    
    res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
});


// ============================================
// STEP 7: START THE SERVER
// ============================================

/**
 * Main startup function
 * 
 * This async function:
 * 1. Tests database connection
 * 2. Starts the server
 * 3. Displays startup information
 */
async function startServer() {
    console.log('');
    console.log('============================================');
    console.log('   🎥 WebRTC Video-Chat Server Starting');
    console.log('============================================');
    console.log('');
    
    // Test database connection
    console.log('📊 Checking database connection...');
    const dbConnected = await testConnection();
    
    if (!dbConnected) {
        console.log('');
        console.log('⚠️  Server will start without database.');
        console.log('   Some features won\'t work until database is set up.');
        console.log('   (This is expected on Day 1 - we\'ll set up the database on Day 2)');
        console.log('');
    }
    
    // Start listening for requests
    server.listen(PORT, () => {
        console.log('');
        console.log('============================================');
        console.log('   ✅ Server is running!');
        console.log('============================================');
        console.log('');
        console.log(`   🌐 Local:    http://localhost:${PORT}`);
        console.log(`   📡 API:      http://localhost:${PORT}/api`);
        console.log(`   ❤️  Health:   http://localhost:${PORT}/api/health`);
        console.log('');
        console.log('   Press Ctrl+C to stop the server');
        console.log('');
        console.log('============================================');
    });
}

// Call the startup function
startServer();

