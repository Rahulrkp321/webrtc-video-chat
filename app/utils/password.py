"""
============================================
PASSWORD UTILITIES
============================================
Handles password hashing and verification using bcrypt.

WHAT IS PASSWORD HASHING?
-------------------------
When a user creates a password like "myPassword123", we NEVER store
it directly in the database. Instead, we convert it to a "hash" - 
a scrambled version that:
1. Cannot be reversed back to the original password
2. Is always the same length (60 characters for bcrypt)
3. Is unique even for the same password (due to "salt")

Example:
    "myPassword123" → "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.qY8VnVYPqM2z"

WHAT IS SALT?
-------------
Salt is random data added before hashing. This ensures that even if
two users have the same password, their hashes are different.

Without salt:
    User1: "password" → "5f4dcc3b5aa765d61d8327deb882cf99"
    User2: "password" → "5f4dcc3b5aa765d61d8327deb882cf99"  (same!)

With salt:
    User1: "password" + "abc123" → "$2b$12$abc123...different1..."
    User2: "password" + "xyz789" → "$2b$12$xyz789...different2..."

WHY BCRYPT?
-----------
- Intentionally slow (prevents brute force attacks)
- Automatically handles salt
- Industry standard for password hashing
============================================
"""

import bcrypt


def hash_password(plain_password: str) -> str:
    """
    Hash a plain text password.
    
    Parameters:
        plain_password (str): The user's plain text password
        
    Returns:
        str: The hashed password (60 characters)
        
    Example:
        >>> hashed = hash_password("myPassword123")
        >>> print(hashed)
        '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/X4.qY8VnVYPqM2z'
        
    HOW IT WORKS:
    1. Convert password string to bytes (bcrypt needs bytes)
    2. Generate a random salt
    3. Hash the password with the salt
    4. Return the hash as a string
    """
    
    # Step 1: Convert string to bytes
    # Python strings are Unicode, but bcrypt needs raw bytes
    password_bytes = plain_password.encode('utf-8')
    
    # Step 2: Generate salt and hash
    # gensalt() creates a random salt with default cost factor of 12
    # Cost factor 12 means 2^12 = 4096 iterations (good balance of security/speed)
    salt = bcrypt.gensalt(rounds=12)
    
    # Step 3: Create the hash
    hashed = bcrypt.hashpw(password_bytes, salt)
    
    # Step 4: Convert bytes back to string for storage
    return hashed.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plain password against a hashed password.
    
    Parameters:
        plain_password (str): The password the user entered (login attempt)
        hashed_password (str): The hash stored in the database
        
    Returns:
        bool: True if password matches, False otherwise
        
    Example:
        >>> hashed = hash_password("myPassword123")
        >>> verify_password("myPassword123", hashed)
        True
        >>> verify_password("wrongPassword", hashed)
        False
        
    HOW IT WORKS:
    1. bcrypt extracts the salt from the stored hash
    2. It hashes the plain password with that same salt
    3. It compares the two hashes
    4. Returns True if they match, False otherwise
    
    WHY THIS IS SECURE:
    - We never decrypt the password (that's impossible with hashing)
    - We hash the attempt and compare hashes
    - Timing attacks are prevented by bcrypt's constant-time comparison
    """
    
    # Convert both to bytes
    password_bytes = plain_password.encode('utf-8')
    hashed_bytes = hashed_password.encode('utf-8')
    
    # bcrypt.checkpw does the comparison securely
    return bcrypt.checkpw(password_bytes, hashed_bytes)


# ============================================
# TEST CODE (runs when file is executed directly)
# ============================================

if __name__ == "__main__":
    print("=" * 50)
    print("Password Hashing Demo")
    print("=" * 50)
    
    # Test password
    test_password = "MySecurePassword123!"
    
    print(f"\nOriginal password: {test_password}")
    print(f"Password length: {len(test_password)} characters")
    
    # Hash it
    hashed = hash_password(test_password)
    print(f"\nHashed password: {hashed}")
    print(f"Hash length: {len(hashed)} characters")
    
    # Verify correct password
    print(f"\nVerifying correct password...")
    result = verify_password(test_password, hashed)
    print(f"Result: {'✅ MATCH' if result else '❌ NO MATCH'}")
    
    # Verify wrong password
    print(f"\nVerifying wrong password...")
    result = verify_password("WrongPassword", hashed)
    print(f"Result: {'✅ MATCH' if result else '❌ NO MATCH'}")
    
    # Show that same password produces different hashes (due to salt)
    print(f"\nHashing same password again...")
    hashed2 = hash_password(test_password)
    print(f"Hash 1: {hashed}")
    print(f"Hash 2: {hashed2}")
    print(f"Same hash? {hashed == hashed2}")
    print("(Different because of random salt!)")

