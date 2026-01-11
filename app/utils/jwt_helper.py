"""
============================================
JWT (JSON Web Token) UTILITIES
============================================
Handles JWT token generation and validation.

WHAT IS JWT?
------------
JWT (JSON Web Token) is like a digital ID card. When you log in:
1. Server creates a JWT with your user info
2. Server signs it with a secret key
3. You receive the token and send it with every request
4. Server verifies the signature to confirm it's authentic

JWT STRUCTURE:
--------------
A JWT has three parts separated by dots:
    xxxxx.yyyyy.zzzzz
    
1. HEADER (xxxxx): Algorithm and token type
   {"alg": "HS256", "typ": "JWT"}
   
2. PAYLOAD (yyyyy): Your data (user_id, expiration, etc.)
   {"user_id": 123, "exp": 1234567890}
   
3. SIGNATURE (zzzzz): Verification hash
   HMACSHA256(base64(header) + "." + base64(payload), secret)

Example Token:
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJ1c2VyX2lkIjoxMjMsImV4cCI6MTIzNDU2Nzg5MH0.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c

WHY JWT?
--------
- Stateless: Server doesn't need to store session data
- Portable: Can be used across different servers
- Secure: Signature prevents tampering
- Self-contained: All needed info is in the token
============================================
"""

import jwt
import os
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Get JWT configuration from environment
JWT_SECRET = os.getenv('JWT_SECRET', 'default-jwt-secret-change-in-production')
JWT_ALGORITHM = 'HS256'  # HMAC with SHA-256
JWT_EXPIRES_IN_DAYS = int(os.getenv('JWT_EXPIRES_IN_DAYS', 7))


def generate_token(user_id: int, username: str = None, email: str = None) -> dict:
    """
    Generate a JWT token for a user.
    
    Parameters:
        user_id (int): The user's ID from the database
        username (str): Optional - user's username
        email (str): Optional - user's email
        
    Returns:
        dict: {
            'token': 'eyJ...',      # The JWT token string
            'expires_at': datetime,  # When the token expires
            'expires_in_days': 7     # Validity period
        }
        
    Example:
        >>> result = generate_token(123, 'john', 'john@example.com')
        >>> print(result['token'])
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
        
    PAYLOAD CONTENTS:
        - user_id: User's database ID
        - username: User's username (for display)
        - email: User's email
        - iat: Issued At (when token was created)
        - exp: Expiration (when token becomes invalid)
    """
    
    # Calculate expiration time
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=JWT_EXPIRES_IN_DAYS)
    
    # Build the payload (data stored in the token)
    payload = {
        # User information
        'user_id': user_id,
        'username': username,
        'email': email,
        
        # Token metadata
        'iat': now,  # Issued At
        'exp': expires_at,  # Expiration
    }
    
    # Create the token
    # jwt.encode(payload, secret, algorithm) → token string
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    
    return {
        'token': token,
        'expires_at': expires_at,
        'expires_in_days': JWT_EXPIRES_IN_DAYS
    }


def decode_token(token: str) -> dict:
    """
    Decode and verify a JWT token.
    
    Parameters:
        token (str): The JWT token string
        
    Returns:
        dict: {
            'valid': True/False,
            'payload': {...} or None,
            'error': None or error message
        }
        
    Example:
        >>> result = decode_token('eyJ...')
        >>> if result['valid']:
        ...     print(f"User ID: {result['payload']['user_id']}")
        ... else:
        ...     print(f"Error: {result['error']}")
        
    WHAT CAN GO WRONG:
    1. Token expired (exp < current time)
    2. Invalid signature (someone tampered with it)
    3. Malformed token (not valid JWT format)
    """
    
    try:
        # Decode and verify the token
        # This checks:
        # - Signature is valid (not tampered)
        # - Token is not expired
        # - Token format is correct
        payload = jwt.decode(
            token, 
            JWT_SECRET, 
            algorithms=[JWT_ALGORITHM]
        )
        
        return {
            'valid': True,
            'payload': payload,
            'error': None
        }
        
    except jwt.ExpiredSignatureError:
        # Token has expired (exp < now)
        return {
            'valid': False,
            'payload': None,
            'error': 'Token has expired'
        }
        
    except jwt.InvalidTokenError as e:
        # Token is invalid (bad signature, malformed, etc.)
        return {
            'valid': False,
            'payload': None,
            'error': f'Invalid token: {str(e)}'
        }


def get_token_from_header(authorization_header: str) -> str:
    """
    Extract token from Authorization header.
    
    The Authorization header format is:
        "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        
    We need to extract just the token part (after "Bearer ").
    
    Parameters:
        authorization_header (str): The full Authorization header value
        
    Returns:
        str: The token string, or None if invalid format
        
    Example:
        >>> header = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        >>> token = get_token_from_header(header)
        >>> print(token)
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    """
    
    if not authorization_header:
        return None
        
    # Check if it starts with "Bearer "
    parts = authorization_header.split(' ')
    
    if len(parts) != 2:
        return None
        
    if parts[0].lower() != 'bearer':
        return None
        
    return parts[1]


# ============================================
# TEST CODE
# ============================================

if __name__ == "__main__":
    print("=" * 50)
    print("JWT Token Demo")
    print("=" * 50)
    
    # Generate a token
    print("\n1. Generating token for user_id=123...")
    result = generate_token(123, 'rahul', 'rahul@example.com')
    token = result['token']
    
    print(f"\nToken: {token[:50]}...")
    print(f"Expires at: {result['expires_at']}")
    print(f"Expires in: {result['expires_in_days']} days")
    
    # Decode the token
    print("\n2. Decoding the token...")
    decoded = decode_token(token)
    
    if decoded['valid']:
        print("✅ Token is valid!")
        print(f"   User ID: {decoded['payload']['user_id']}")
        print(f"   Username: {decoded['payload']['username']}")
        print(f"   Email: {decoded['payload']['email']}")
    else:
        print(f"❌ Token is invalid: {decoded['error']}")
    
    # Test invalid token
    print("\n3. Testing with invalid token...")
    decoded = decode_token("invalid.token.here")
    print(f"   Valid: {decoded['valid']}")
    print(f"   Error: {decoded['error']}")
    
    # Test Bearer header extraction
    print("\n4. Testing header extraction...")
    header = f"Bearer {token}"
    extracted = get_token_from_header(header)
    print(f"   Header: Bearer xxx...")
    print(f"   Extracted: {'✅ Success' if extracted == token else '❌ Failed'}")

