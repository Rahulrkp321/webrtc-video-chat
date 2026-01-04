"""
============================================
MAIN ROUTES
============================================
Handles main page routes (non-API).

These routes serve HTML pages to users.
============================================
"""

from flask import render_template, send_from_directory, current_app
from app.routes import main_bp
import os


@main_bp.route('/')
def index():
    """
    Home Page
    
    URL: GET /
    Returns: The main landing page (index.html)
    
    WHAT IS render_template?
    Flask uses Jinja2 templating engine. render_template
    finds HTML files in the 'templates' folder and returns them.
    """
    return render_template('index.html')


@main_bp.route('/login')
def login_page():
    """Login Page"""
    return render_template('login.html')


@main_bp.route('/register')
def register_page():
    """Registration Page"""
    return render_template('register.html')


@main_bp.route('/dashboard')
def dashboard_page():
    """User Dashboard Page"""
    return render_template('dashboard.html')


@main_bp.route('/room/<room_code>')
def room_page(room_code):
    """
    Video Chat Room Page
    
    URL: GET /room/<room_code>
    Example: /room/ABC-123-XYZ
    
    The <room_code> part is a URL variable that Flask captures
    and passes to our function as a parameter.
    """
    return render_template('room.html', room_code=room_code)


@main_bp.route('/history')
def history_page():
    """Call History Page"""
    return render_template('history.html')


@main_bp.route('/contacts')
def contacts_page():
    """Contacts Page"""
    return render_template('contacts.html')

