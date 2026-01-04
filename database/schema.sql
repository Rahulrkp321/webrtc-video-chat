-- ============================================
-- WebRTC Video-Chat Database Schema
-- ============================================
-- Database: RTC_Video_Chat_DB
-- Framework: Python (Flask) + MySQL
-- Naming Convention: Stored Procedures prefix 'dt_vc_'
-- ============================================
-- AUDIT FIELDS (included in all tables):
--   is_active: Whether record is active (1=yes, 0=no)
--   is_deleted: Soft delete flag (1=deleted, 0=not deleted)
--   remarks: Notes or comments about the record
--   created_dt: When record was created
--   created_by: User ID who created the record
--   updated_dt: When record was last updated
--   updated_by: User ID who last updated the record
-- ============================================

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS RTC_Video_Chat_DB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Use the database
USE RTC_Video_Chat_DB;

-- ============================================
-- TABLE 1: USERS
-- ============================================
-- Stores user account information
-- Primary Key: user_id (auto-increment numeric)
-- ============================================

DROP TABLE IF EXISTS users;

CREATE TABLE users (
    -- Primary Key
    user_id         INT             NOT NULL AUTO_INCREMENT,
    
    -- User Information
    username        VARCHAR(50)     NOT NULL,
    email           VARCHAR(100)    NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    display_name    VARCHAR(100)    NULL,
    avatar_url      VARCHAR(500)    NULL,
    
    -- Status
    online_status   ENUM('online', 'offline', 'busy', 'away') DEFAULT 'offline',
    last_seen       DATETIME        NULL,
    
    -- Audit Fields
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    remarks         TEXT            NULL,
    created_dt      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      INT             NULL,
    updated_dt      DATETIME        NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by      INT             NULL,
    
    -- Constraints
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_email (email),
    INDEX idx_online_status (online_status),
    INDEX idx_is_active (is_active),
    INDEX idx_is_deleted (is_deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- TABLE 2: SESSIONS
-- ============================================
-- Stores user login sessions (JWT tokens)
-- Primary Key: session_id (auto-increment numeric)
-- ============================================

DROP TABLE IF EXISTS sessions;

CREATE TABLE sessions (
    -- Primary Key
    session_id      INT             NOT NULL AUTO_INCREMENT,
    
    -- Session Information
    user_id         INT             NOT NULL,
    token           VARCHAR(500)    NOT NULL,
    ip_address      VARCHAR(45)     NULL,
    user_agent      VARCHAR(500)    NULL,
    expires_at      DATETIME        NOT NULL,
    
    -- Audit Fields
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    remarks         TEXT            NULL,
    created_dt      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      INT             NULL,
    updated_dt      DATETIME        NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by      INT             NULL,
    
    -- Constraints
    PRIMARY KEY (session_id),
    INDEX idx_user_id (user_id),
    INDEX idx_token (token(255)),
    INDEX idx_expires_at (expires_at),
    CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- TABLE 3: ROOMS
-- ============================================
-- Stores video chat rooms
-- Primary Key: room_id (auto-increment numeric)
-- ============================================

DROP TABLE IF EXISTS room_participants;
DROP TABLE IF EXISTS rooms;

CREATE TABLE rooms (
    -- Primary Key
    room_id         INT             NOT NULL AUTO_INCREMENT,
    
    -- Room Information
    room_code       VARCHAR(20)     NOT NULL,
    room_name       VARCHAR(100)    NULL,
    host_user_id    INT             NOT NULL,
    
    -- Room Settings
    max_participants INT            NOT NULL DEFAULT 10,
    is_private      TINYINT(1)      NOT NULL DEFAULT 0,
    password_hash   VARCHAR(255)    NULL,
    
    -- Status
    room_status     ENUM('waiting', 'active', 'ended') DEFAULT 'waiting',
    started_at      DATETIME        NULL,
    ended_at        DATETIME        NULL,
    
    -- Audit Fields
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    remarks         TEXT            NULL,
    created_dt      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      INT             NULL,
    updated_dt      DATETIME        NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by      INT             NULL,
    
    -- Constraints
    PRIMARY KEY (room_id),
    UNIQUE KEY uk_room_code (room_code),
    INDEX idx_host_user_id (host_user_id),
    INDEX idx_room_status (room_status),
    INDEX idx_is_active (is_active),
    CONSTRAINT fk_room_host FOREIGN KEY (host_user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- TABLE 4: ROOM_PARTICIPANTS
-- ============================================
-- Tracks who is/was in each room
-- Primary Key: participant_id (auto-increment numeric)
-- ============================================

CREATE TABLE room_participants (
    -- Primary Key
    participant_id  INT             NOT NULL AUTO_INCREMENT,
    
    -- Participation Information
    room_id         INT             NOT NULL,
    user_id         INT             NOT NULL,
    
    -- Status
    join_time       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leave_time      DATETIME        NULL,
    participant_status ENUM('connected', 'disconnected', 'left') DEFAULT 'connected',
    
    -- Media State
    is_audio_on     TINYINT(1)      NOT NULL DEFAULT 1,
    is_video_on     TINYINT(1)      NOT NULL DEFAULT 1,
    is_screen_sharing TINYINT(1)    NOT NULL DEFAULT 0,
    
    -- Audit Fields
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    remarks         TEXT            NULL,
    created_dt      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      INT             NULL,
    updated_dt      DATETIME        NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by      INT             NULL,
    
    -- Constraints
    PRIMARY KEY (participant_id),
    INDEX idx_room_id (room_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (participant_status),
    CONSTRAINT fk_participant_room FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_participant_user FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- TABLE 5: CONTACTS
-- ============================================
-- Stores user contact relationships
-- Primary Key: contact_id (auto-increment numeric)
-- ============================================

DROP TABLE IF EXISTS contacts;

CREATE TABLE contacts (
    -- Primary Key
    contact_id      INT             NOT NULL AUTO_INCREMENT,
    
    -- Contact Relationship
    user_id         INT             NOT NULL,
    contact_user_id INT             NOT NULL,
    
    -- Contact Info
    nickname        VARCHAR(100)    NULL,
    contact_status  ENUM('pending', 'accepted', 'blocked') DEFAULT 'accepted',
    
    -- Audit Fields
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    remarks         TEXT            NULL,
    created_dt      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      INT             NULL,
    updated_dt      DATETIME        NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by      INT             NULL,
    
    -- Constraints
    PRIMARY KEY (contact_id),
    UNIQUE KEY uk_contact (user_id, contact_user_id),
    INDEX idx_user_id (user_id),
    INDEX idx_contact_user_id (contact_user_id),
    INDEX idx_status (contact_status),
    CONSTRAINT fk_contact_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_contact_target FOREIGN KEY (contact_user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- TABLE 6: CALL_LOGS
-- ============================================
-- Records call history
-- Primary Key: call_id (auto-increment numeric)
-- ============================================

DROP TABLE IF EXISTS call_logs;

CREATE TABLE call_logs (
    -- Primary Key
    call_id         INT             NOT NULL AUTO_INCREMENT,
    
    -- Call Information
    room_id         INT             NULL,
    caller_id       INT             NOT NULL,
    callee_id       INT             NULL,
    
    -- Call Details
    call_type       ENUM('one-to-one', 'group') DEFAULT 'one-to-one',
    call_status     ENUM('initiated', 'ringing', 'answered', 'rejected', 'missed', 'ended') DEFAULT 'initiated',
    start_time      DATETIME        NULL,
    end_time        DATETIME        NULL,
    duration_seconds INT            NULL,
    
    -- Audit Fields
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    remarks         TEXT            NULL,
    created_dt      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      INT             NULL,
    updated_dt      DATETIME        NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by      INT             NULL,
    
    -- Constraints
    PRIMARY KEY (call_id),
    INDEX idx_room_id (room_id),
    INDEX idx_caller_id (caller_id),
    INDEX idx_callee_id (callee_id),
    INDEX idx_call_status (call_status),
    INDEX idx_start_time (start_time),
    CONSTRAINT fk_call_room FOREIGN KEY (room_id) REFERENCES rooms(room_id),
    CONSTRAINT fk_call_caller FOREIGN KEY (caller_id) REFERENCES users(user_id),
    CONSTRAINT fk_call_callee FOREIGN KEY (callee_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- TABLE 7: ICE_CANDIDATES
-- ============================================
-- Stores ICE candidates for WebRTC connections
-- Primary Key: candidate_id (auto-increment numeric)
-- ============================================

DROP TABLE IF EXISTS ice_candidates;

CREATE TABLE ice_candidates (
    -- Primary Key
    candidate_id    INT             NOT NULL AUTO_INCREMENT,
    
    -- ICE Information
    room_id         INT             NOT NULL,
    from_user_id    INT             NOT NULL,
    to_user_id      INT             NOT NULL,
    candidate       TEXT            NOT NULL,
    sdp_mid         VARCHAR(50)     NULL,
    sdp_m_line_index INT            NULL,
    
    -- Audit Fields
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    is_deleted      TINYINT(1)      NOT NULL DEFAULT 0,
    remarks         TEXT            NULL,
    created_dt      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      INT             NULL,
    updated_dt      DATETIME        NULL ON UPDATE CURRENT_TIMESTAMP,
    updated_by      INT             NULL,
    
    -- Constraints
    PRIMARY KEY (candidate_id),
    INDEX idx_room_id (room_id),
    INDEX idx_from_user (from_user_id),
    INDEX idx_to_user (to_user_id),
    CONSTRAINT fk_ice_room FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_ice_from FOREIGN KEY (from_user_id) REFERENCES users(user_id),
    CONSTRAINT fk_ice_to FOREIGN KEY (to_user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================
-- VERIFICATION QUERY
-- ============================================
-- Run this to verify all tables were created

SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    CREATE_TIME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'RTC_Video_Chat_DB'
ORDER BY TABLE_NAME;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT 'Schema creation completed successfully!' AS message;
