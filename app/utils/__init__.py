"""
============================================
UTILS PACKAGE
============================================
Contains utility functions used across the application.

Modules:
- password.py: Password hashing and verification
- jwt_helper.py: JWT token generation and validation
============================================
"""

from app.utils.password import hash_password, verify_password
from app.utils.jwt_helper import generate_token, decode_token

