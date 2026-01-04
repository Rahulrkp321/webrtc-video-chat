"""
============================================
WebRTC Video-Chat Application
============================================
Main entry point for the Flask application.

Run with: python run.py
Or: flask run

This file:
1. Creates the Flask application
2. Tests database connection
3. Starts the server with SocketIO support
============================================
"""

import os
import eventlet

# Monkey-patch standard library for async support
# This MUST be done before importing Flask
eventlet.monkey_patch()

from app import create_app, socketio
from app.config.database import db
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Create Flask application
app = create_app()


def main():
    """
    Main startup function.
    
    1. Displays startup banner
    2. Tests database connection
    3. Starts the Flask-SocketIO server
    """
    
    print('')
    print('=' * 50)
    print('   🎥 WebRTC Video-Chat Server Starting')
    print('   Framework: Flask (Python)')
    print('=' * 50)
    print('')
    
    # Test database connection
    print('📊 Checking database connection...')
    db_connected = db.test_connection()
    
    if not db_connected:
        print('')
        print("⚠️  Server will start without database.")
        print("   Some features won't work until database is set up.")
        print('')
    
    # Get configuration
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', 3000))
    debug = os.getenv('FLASK_DEBUG', 'True').lower() == 'true'
    
    print('')
    print('=' * 50)
    print('   ✅ Server is running!')
    print('=' * 50)
    print('')
    print(f'   🌐 Local:    http://localhost:{port}')
    print(f'   📡 API:      http://localhost:{port}/api')
    print(f'   ❤️  Health:   http://localhost:{port}/api/health')
    print('')
    print('   Press Ctrl+C to stop the server')
    print('')
    print('=' * 50)
    
    # Start the server with SocketIO
    # use_reloader=False because eventlet doesn't work well with it
    socketio.run(app, host=host, port=port, debug=debug, use_reloader=False)


if __name__ == '__main__':
    main()

