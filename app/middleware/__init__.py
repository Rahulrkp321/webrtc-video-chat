"""
============================================
MIDDLEWARE PACKAGE
============================================
Contains middleware functions that run before route handlers.

Modules:
- auth_middleware.py: Authentication and authorization checks
============================================
"""

from app.middleware.auth_middleware import token_required, get_current_user

