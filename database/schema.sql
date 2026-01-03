-- ============================================
-- WebRTC Video-Chat Database Schema
-- ============================================
-- Database Name: RTC_Video_Chat_DB
-- Created: Day 2 of Development
-- 
-- NAMING CONVENTIONS:
-- - Tables: lowercase with underscores (snake_case)
-- - Primary Keys: table_name_id (e.g., user_id)
-- - Foreign Keys: referenced_table_id
-- - Stored Procedures: dt_vc_action_entity
--
-- AUDIT FIELDS (Required on ALL tables):
-- - is_active: Boolean - Is this record currently active?
-- - is_deleted: Boolean - Soft delete flag (never truly delete)
-- - remarks: Text - Notes or comments about the record
-- - created_dt: DateTime - When was this record created?
-- - created_by: Int - User ID who created this record
-- - updated_dt: DateTime - When was this record last updated?
-- - updated_by: Int - User ID who last updated this record
-- ============================================

-- Use the database
USE RTC_Video_Chat_DB;

-- ============================================
-- TABLE 1: users
-- ============================================
-- PURPOSE: Store registered user accounts
-- 
-- This table holds all user information including:
-- - Login credentials (username, email, password)
-- - Profile information (display name, avatar)
-- - Online status (is_online, last_seen)
-- ============================================

DROP TABLE IF EXISTS room_participants;
DROP TABLE IF EXISTS call_logs;
DROP TABLE IF EXISTS contacts;
DROP TABLE IF EXISTS user_sessions;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    -- PRIMARY KEY
    -- Auto-increment integer (NOT UUID as per requirements)
    user_id             INT PRIMARY KEY AUTO_INCREMENT,
    
    -- LOGIN CREDENTIALS
    -- Username: Unique identifier chosen by user (e.g., "john_doe")
    username            VARCHAR(50) UNIQUE NOT NULL,
    
    -- Email: Used for login and notifications
    email               VARCHAR(100) UNIQUE NOT NULL,
    
    -- Password Hash: NEVER store plain text passwords!
    -- We use bcrypt which creates a hash like: $2a$10$N9qo8uLOickgx2ZMRZoMy...
    password_hash       VARCHAR(255) NOT NULL,
    
    -- PROFILE INFORMATION
    -- Display Name: What other users see (e.g., "John Doe")
    display_name        VARCHAR(100),
    
    -- Avatar URL: Link to profile picture
    avatar_url          VARCHAR(255),
    
    -- ONLINE STATUS
    -- Is Online: TRUE if user is currently connected
    is_online           BOOLEAN DEFAULT FALSE,
    
    -- Last Seen: When user was last active
    last_seen           DATETIME,
    
    -- ========================================
    -- AUDIT FIELDS (Required on all tables)
    -- ========================================
    -- Is Active: FALSE means account is deactivated
    is_active           BOOLEAN DEFAULT TRUE,
    
    -- Is Deleted: TRUE means soft-deleted (not visible but data preserved)
    is_deleted          BOOLEAN DEFAULT FALSE,
    
    -- Remarks: Admin notes about this user
    remarks             TEXT,
    
    -- Created DateTime: When account was created
    created_dt          DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Created By: User ID who created this (NULL for self-registration)
    created_by          INT,
    
    -- Updated DateTime: Auto-updates when row changes
    updated_dt          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Updated By: User ID who last modified this record
    updated_by          INT
);

-- Add index for faster email lookups (used in login)
CREATE INDEX idx_users_email ON users(email);

-- Add index for username searches
CREATE INDEX idx_users_username ON users(username);


-- ============================================
-- TABLE 2: rooms
-- ============================================
-- PURPOSE: Store video chat rooms
--
-- Each room has:
-- - Unique room code (like "abc-def-ghi" for sharing)
-- - Owner (who created the room)
-- - Privacy settings (public/private with password)
-- - Participant limit
-- ============================================

CREATE TABLE rooms (
    -- PRIMARY KEY
    room_id             INT PRIMARY KEY AUTO_INCREMENT,
    
    -- ROOM IDENTIFICATION
    -- Room Code: Unique shareable code (e.g., "abc-123-xyz")
    -- This is what users share to invite others
    room_code           VARCHAR(20) UNIQUE NOT NULL,
    
    -- Room Name: Human-readable name (e.g., "Team Meeting")
    room_name           VARCHAR(100),
    
    -- OWNERSHIP
    -- Owner User ID: Who created this room
    owner_user_id       INT,
    
    -- PRIVACY SETTINGS
    -- Is Private: If TRUE, requires password to join
    is_private          BOOLEAN DEFAULT FALSE,
    
    -- Password Hash: For private rooms (hashed, never plain text)
    password_hash       VARCHAR(255),
    
    -- CAPACITY
    -- Max Participants: How many people can join (default 10)
    max_participants    INT DEFAULT 10,
    
    -- Current Participants: How many are currently in the room
    current_participants INT DEFAULT 0,
    
    -- ========================================
    -- AUDIT FIELDS
    -- ========================================
    is_active           BOOLEAN DEFAULT TRUE,
    is_deleted          BOOLEAN DEFAULT FALSE,
    remarks             TEXT,
    created_dt          DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by          INT,
    updated_dt          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          INT,
    
    -- FOREIGN KEY: Links to users table
    FOREIGN KEY (owner_user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- Index for room code lookups (used when joining)
CREATE INDEX idx_rooms_code ON rooms(room_code);

-- Index for owner lookups (find user's rooms)
CREATE INDEX idx_rooms_owner ON rooms(owner_user_id);


-- ============================================
-- TABLE 3: room_participants
-- ============================================
-- PURPOSE: Track who is in each room
--
-- This is a junction table that connects users to rooms
-- It tracks:
-- - When they joined/left
-- - If they're the host
-- - Their mute/video status
-- ============================================

CREATE TABLE room_participants (
    -- PRIMARY KEY
    participant_id      INT PRIMARY KEY AUTO_INCREMENT,
    
    -- RELATIONSHIPS
    -- Which room
    room_id             INT NOT NULL,
    
    -- Which user
    user_id             INT NOT NULL,
    
    -- TIMING
    -- When they joined
    joined_at           DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- When they left (NULL if still in room)
    left_at             DATETIME,
    
    -- ROLE & STATUS
    -- Is Host: TRUE if this user is the room host
    is_host             BOOLEAN DEFAULT FALSE,
    
    -- Is Muted: TRUE if their microphone is muted
    is_muted            BOOLEAN DEFAULT FALSE,
    
    -- Is Video Off: TRUE if their camera is off
    is_video_off        BOOLEAN DEFAULT FALSE,
    
    -- ========================================
    -- AUDIT FIELDS
    -- ========================================
    is_active           BOOLEAN DEFAULT TRUE,
    is_deleted          BOOLEAN DEFAULT FALSE,
    remarks             TEXT,
    created_dt          DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by          INT,
    updated_dt          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          INT,
    
    -- FOREIGN KEYS
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Index for finding participants in a room
CREATE INDEX idx_participants_room ON room_participants(room_id);

-- Index for finding which rooms a user is in
CREATE INDEX idx_participants_user ON room_participants(user_id);


-- ============================================
-- TABLE 4: call_logs
-- ============================================
-- PURPOSE: History of all video calls
--
-- Records:
-- - Who called whom
-- - When the call started/ended
-- - Duration
-- - Status (completed, missed, declined, failed)
-- ============================================

CREATE TABLE call_logs (
    -- PRIMARY KEY
    call_id             INT PRIMARY KEY AUTO_INCREMENT,
    
    -- RELATIONSHIPS
    -- Which room the call was in
    room_id             INT,
    
    -- Who initiated the call
    caller_user_id      INT,
    
    -- Who received the call
    callee_user_id      INT,
    
    -- TIMING
    -- When call started
    started_at          DATETIME,
    
    -- When call ended
    ended_at            DATETIME,
    
    -- Duration in seconds (calculated when call ends)
    duration_seconds    INT,
    
    -- STATUS
    -- Call outcome: completed, missed, declined, failed
    call_status         ENUM('completed', 'missed', 'declined', 'failed') DEFAULT 'completed',
    
    -- ========================================
    -- AUDIT FIELDS
    -- ========================================
    is_active           BOOLEAN DEFAULT TRUE,
    is_deleted          BOOLEAN DEFAULT FALSE,
    remarks             TEXT,
    created_dt          DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by          INT,
    updated_dt          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          INT,
    
    -- FOREIGN KEYS
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE SET NULL,
    FOREIGN KEY (caller_user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (callee_user_id) REFERENCES users(user_id) ON DELETE SET NULL
);

-- Index for finding a user's call history
CREATE INDEX idx_calls_caller ON call_logs(caller_user_id);
CREATE INDEX idx_calls_callee ON call_logs(callee_user_id);

-- Index for date-based queries
CREATE INDEX idx_calls_date ON call_logs(started_at);


-- ============================================
-- TABLE 5: contacts
-- ============================================
-- PURPOSE: User's contact/friend list
--
-- Allows users to:
-- - Save frequently called contacts
-- - Give contacts nicknames
-- - Quick-call from contact list
-- ============================================

CREATE TABLE contacts (
    -- PRIMARY KEY
    contact_id          INT PRIMARY KEY AUTO_INCREMENT,
    
    -- RELATIONSHIPS
    -- The user who owns this contact
    user_id             INT NOT NULL,
    
    -- The contact (another user)
    contact_user_id     INT NOT NULL,
    
    -- CONTACT INFO
    -- Nickname: Custom name for this contact (e.g., "Mom", "Boss")
    nickname            VARCHAR(100),
    
    -- ========================================
    -- AUDIT FIELDS
    -- ========================================
    is_active           BOOLEAN DEFAULT TRUE,
    is_deleted          BOOLEAN DEFAULT FALSE,
    remarks             TEXT,
    created_dt          DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by          INT,
    updated_dt          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          INT,
    
    -- FOREIGN KEYS
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (contact_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    
    -- UNIQUE CONSTRAINT: Can't add same contact twice
    UNIQUE KEY unique_contact (user_id, contact_user_id)
);

-- Index for finding a user's contacts
CREATE INDEX idx_contacts_user ON contacts(user_id);


-- ============================================
-- TABLE 6: user_sessions
-- ============================================
-- PURPOSE: Track user login sessions
--
-- Used for:
-- - JWT token validation
-- - Multiple device login
-- - Session management (logout from all devices)
-- ============================================

CREATE TABLE user_sessions (
    -- PRIMARY KEY
    session_id          INT PRIMARY KEY AUTO_INCREMENT,
    
    -- RELATIONSHIPS
    -- Which user this session belongs to
    user_id             INT NOT NULL,
    
    -- SESSION DATA
    -- Token Hash: Hashed JWT token for validation
    token_hash          VARCHAR(255) NOT NULL,
    
    -- Expires At: When this session expires
    expires_at          DATETIME NOT NULL,
    
    -- DEVICE INFO
    -- IP Address: Where the login came from
    ip_address          VARCHAR(45),
    
    -- User Agent: Browser/device information
    user_agent          VARCHAR(255),
    
    -- ========================================
    -- AUDIT FIELDS
    -- ========================================
    is_active           BOOLEAN DEFAULT TRUE,
    is_deleted          BOOLEAN DEFAULT FALSE,
    remarks             TEXT,
    created_dt          DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by          INT,
    updated_dt          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    updated_by          INT,
    
    -- FOREIGN KEY
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Index for token lookups (used in every authenticated request)
CREATE INDEX idx_sessions_token ON user_sessions(token_hash);

-- Index for finding a user's sessions
CREATE INDEX idx_sessions_user ON user_sessions(user_id);

-- Index for expired session cleanup
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);


-- ============================================
-- VERIFICATION: Show all created tables
-- ============================================
SHOW TABLES;

