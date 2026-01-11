"""
============================================
WebRTC Video-Chat Application
============================================
Flask Application Factory

This file creates and configures the Flask application.
Using the "Application Factory" pattern allows:
- Multiple instances for testing
- Different configurations for dev/prod
- Cleaner organization

WHAT IS FLASK?
Flask is a web framework for Python. It handles:
- HTTP requests (GET, POST, etc.)
- URL routing (which function handles which URL)
- Template rendering (HTML pages)
- And much more!
============================================
"""

from flask import Flask
from flask_cors import CORS
from flask_socketio import SocketIO
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

# Create SocketIO instance (will be initialized with app later)
# SocketIO enables real-time bidirectional communication
socketio = SocketIO()


def create_app(config_name='development'):
    """
    Application Factory Function
    
    Creates and configures a Flask application instance.
    
    Parameters:
        config_name (str): Which configuration to use ('development', 'production', 'testing')
    
    Returns:
        Flask: Configured Flask application instance
    
    WHAT IS AN APPLICATION FACTORY?
    Instead of creating the app globally, we create it inside a function.
    This allows us to create multiple instances with different configs.
    """
    
    # Create Flask application
    # __name__ tells Flask where to look for resources
    app = Flask(__name__, 
                template_folder='templates',
                static_folder='static')
    
    # ============================================
    # CONFIGURATION
    # ============================================
    
    # Secret key for sessions and security
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')
    
    # Database configuration
    app.config['DB_HOST'] = os.getenv('DB_HOST', 'localhost')
    app.config['DB_PORT'] = int(os.getenv('DB_PORT', 3306))
    app.config['DB_USER'] = os.getenv('DB_USER', 'root')
    app.config['DB_PASSWORD'] = os.getenv('DB_PASSWORD', '')
    app.config['DB_NAME'] = os.getenv('DB_NAME', 'RTC_Video_Chat_DB')
    
    # JWT configuration
    app.config['JWT_SECRET'] = os.getenv('JWT_SECRET', 'jwt-secret-key')
    app.config['JWT_EXPIRES_IN_DAYS'] = int(os.getenv('JWT_EXPIRES_IN_DAYS', 7))
    
    # Application settings
    app.config['MAX_PARTICIPANTS_PER_ROOM'] = int(os.getenv('MAX_PARTICIPANTS_PER_ROOM', 10))
    
    # ============================================
    # INITIALIZE EXTENSIONS
    # ============================================
    
    # Enable CORS (Cross-Origin Resource Sharing)
    # This allows the frontend to make requests to our API
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    
    # Initialize SocketIO with the app
    socketio.init_app(app, cors_allowed_origins="*", async_mode='eventlet')
    
    # ============================================
    # REGISTER BLUEPRINTS (Route Groups)
    # ============================================
    
    # Import and register blueprints
    from app.routes import main_bp, api_bp, auth_bp
    
    # Main pages (/, /login, /register, etc.)
    app.register_blueprint(main_bp)
    
    # General API routes (/api, /api/health, etc.)
    app.register_blueprint(api_bp, url_prefix='/api')
    
    # Authentication routes (/api/auth/register, /api/auth/login, etc.)
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    
    # ============================================
    # ERROR HANDLERS
    # ============================================
    
    @app.errorhandler(404)
    def not_found_error(error):
        """Handle 404 Not Found errors"""
        from flask import jsonify, request
        if request.path.startswith('/api'):
            return jsonify({
                'success': False,
                'message': 'API endpoint not found',
                'path': request.path
            }), 404
        return app.send_static_file('index.html')
    
    @app.errorhandler(500)
    def internal_error(error):
        """Handle 500 Internal Server errors"""
        from flask import jsonify
        return jsonify({
            'success': False,
            'message': 'Internal server error'
        }), 500
    
    return app

