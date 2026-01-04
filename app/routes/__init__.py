"""
============================================
ROUTES PACKAGE
============================================
Contains all route definitions (URL endpoints).

WHAT ARE ROUTES?
Routes map URLs to Python functions. When someone visits
a URL, the corresponding function is executed.

Example:
    @app.route('/hello')
    def hello():
        return 'Hello World!'
    
    When someone visits http://localhost:3000/hello,
    they see "Hello World!"

WHAT ARE BLUEPRINTS?
Blueprints are a way to organize routes into groups.
Instead of putting all routes in one file, we split them:
- main_bp: Main pages (home, etc.)
- api_bp: API endpoints (/api/...)
============================================
"""

from flask import Blueprint

# ============================================
# MAIN BLUEPRINT
# ============================================
# Handles main pages (non-API routes)
main_bp = Blueprint('main', __name__)

# ============================================
# API BLUEPRINT
# ============================================
# Handles API endpoints (prefixed with /api)
api_bp = Blueprint('api', __name__)


# ============================================
# IMPORT ROUTE HANDLERS
# ============================================
# These imports register the route handlers with blueprints
from app.routes import main_routes
from app.routes import api_routes

