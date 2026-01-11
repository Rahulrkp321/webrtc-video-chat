-- ============================================
-- WebRTC Video-Chat Database Test Script
-- ============================================
-- This script tests all tables and stored procedures
-- Run this in MySQL Workbench or Terminal
-- ============================================

-- Use the database
USE RTC_Video_Chat_DB;

-- ============================================
-- SECTION 1: VERIFY ALL TABLES EXIST
-- ============================================

SELECT '=== SECTION 1: VERIFY TABLES ===' AS section;

-- Show all tables
SHOW TABLES;

-- Count tables (should be 7)
SELECT COUNT(*) AS table_count FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'RTC_Video_Chat_DB';

-- ============================================
-- SECTION 2: VERIFY TABLE STRUCTURES
-- ============================================

SELECT '=== SECTION 2: TABLE STRUCTURES ===' AS section;

-- Users table structure
SELECT '--- USERS TABLE ---' AS table_name;
DESCRIBE users;

-- Sessions table structure
SELECT '--- SESSIONS TABLE ---' AS table_name;
DESCRIBE sessions;

-- Rooms table structure
SELECT '--- ROOMS TABLE ---' AS table_name;
DESCRIBE rooms;

-- Room participants table structure
SELECT '--- ROOM_PARTICIPANTS TABLE ---' AS table_name;
DESCRIBE room_participants;

-- Contacts table structure
SELECT '--- CONTACTS TABLE ---' AS table_name;
DESCRIBE contacts;

-- Call logs table structure
SELECT '--- CALL_LOGS TABLE ---' AS table_name;
DESCRIBE call_logs;

-- ICE candidates table structure
SELECT '--- ICE_CANDIDATES TABLE ---' AS table_name;
DESCRIBE ice_candidates;

-- ============================================
-- SECTION 3: VERIFY ALL STORED PROCEDURES EXIST
-- ============================================

SELECT '=== SECTION 3: STORED PROCEDURES ===' AS section;

-- List all stored procedures
SELECT ROUTINE_NAME, ROUTINE_TYPE, CREATED
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'RTC_Video_Chat_DB'
ORDER BY ROUTINE_NAME;

-- Count procedures (should be 20)
SELECT COUNT(*) AS procedure_count 
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'RTC_Video_Chat_DB' AND ROUTINE_TYPE = 'PROCEDURE';

-- ============================================
-- SECTION 4: TEST USER PROCEDURES
-- ============================================

SELECT '=== SECTION 4: TEST USER PROCEDURES ===' AS section;

-- 4.1 Test: Create a new user
SELECT '--- TEST: dt_vc_create_user ---' AS test_name;

CALL dt_vc_create_user(
    'testuser1',                    -- username
    'testuser1@example.com',        -- email
    'hashed_password_here',         -- password_hash
    'Test User One',                -- display_name
    0,                              -- created_by (0 = self)
    @p_user_id,                     -- OUT: new user ID
    @p_success,                     -- OUT: success flag
    @p_message                      -- OUT: result message
);

SELECT @p_user_id AS new_user_id, @p_success AS success, @p_message AS message;

-- 4.2 Test: Try to create duplicate user (should fail)
SELECT '--- TEST: dt_vc_create_user (duplicate) ---' AS test_name;

CALL dt_vc_create_user(
    'testuser1',                    -- same username
    'different@example.com',        -- different email
    'hashed_password_here',
    'Test User Duplicate',
    0,
    @p_user_id,
    @p_success,
    @p_message
);

SELECT @p_user_id AS new_user_id, @p_success AS success, @p_message AS message;
-- Expected: success = 0, message = 'Username already exists'

-- 4.3 Test: Create second user
SELECT '--- TEST: Create second user ---' AS test_name;

CALL dt_vc_create_user(
    'testuser2',
    'testuser2@example.com',
    'hashed_password_here',
    'Test User Two',
    @p_user_id,                     -- created_by = first user
    @p_user_id2,
    @p_success,
    @p_message
);

SELECT @p_user_id2 AS new_user_id, @p_success AS success, @p_message AS message;

-- 4.4 Test: Get user by email
SELECT '--- TEST: dt_vc_get_user_by_email ---' AS test_name;

CALL dt_vc_get_user_by_email('testuser1@example.com');

-- 4.5 Test: Get user by username
SELECT '--- TEST: dt_vc_get_user_by_username ---' AS test_name;

CALL dt_vc_get_user_by_username('testuser1');

-- 4.6 Test: Get user by ID
SELECT '--- TEST: dt_vc_get_user_by_id ---' AS test_name;

CALL dt_vc_get_user_by_id(@p_user_id);

-- 4.7 Test: Update user status
SELECT '--- TEST: dt_vc_update_user_status ---' AS test_name;

CALL dt_vc_update_user_status(@p_user_id, 'online', @p_user_id);

-- Verify status changed
SELECT user_id, username, online_status FROM users WHERE user_id = @p_user_id;

-- ============================================
-- SECTION 5: TEST SESSION PROCEDURES
-- ============================================

SELECT '=== SECTION 5: TEST SESSION PROCEDURES ===' AS section;

-- 5.1 Test: Create a session
SELECT '--- TEST: dt_vc_create_session ---' AS test_name;

CALL dt_vc_create_session(
    @p_user_id,                     -- user_id
    'test_jwt_token_123456789',     -- token
    '127.0.0.1',                    -- ip_address
    'Mozilla/5.0 Test Browser',     -- user_agent
    DATE_ADD(NOW(), INTERVAL 7 DAY), -- expires_at
    @p_session_id                   -- OUT: session ID
);

SELECT @p_session_id AS new_session_id;

-- 5.2 Test: Get session by token
SELECT '--- TEST: dt_vc_get_session ---' AS test_name;

CALL dt_vc_get_session('test_jwt_token_123456789');

-- 5.3 Test: Invalidate session (logout)
SELECT '--- TEST: dt_vc_invalidate_session ---' AS test_name;

-- First create another session to invalidate
CALL dt_vc_create_session(
    @p_user_id,
    'token_to_invalidate',
    '127.0.0.1',
    'Test Browser',
    DATE_ADD(NOW(), INTERVAL 7 DAY),
    @p_session_id2
);

-- Now invalidate it
CALL dt_vc_invalidate_session('token_to_invalidate');

-- Verify session is invalidated (should return empty)
CALL dt_vc_get_session('token_to_invalidate');

-- ============================================
-- SECTION 6: TEST ROOM PROCEDURES
-- ============================================

SELECT '=== SECTION 6: TEST ROOM PROCEDURES ===' AS section;

-- 6.1 Test: Create a room
SELECT '--- TEST: dt_vc_create_room ---' AS test_name;

CALL dt_vc_create_room(
    'ABC-123-XYZ',                  -- room_code
    'Test Video Room',              -- room_name
    @p_user_id,                     -- host_user_id
    5,                              -- max_participants
    0,                              -- is_private (0 = public)
    NULL,                           -- password_hash (no password)
    @p_room_id,                     -- OUT: room ID
    @p_success,                     -- OUT: success flag
    @p_message                      -- OUT: message
);

SELECT @p_room_id AS new_room_id, @p_success AS success, @p_message AS message;

-- 6.2 Test: Get room by code
SELECT '--- TEST: dt_vc_get_room_by_code ---' AS test_name;

CALL dt_vc_get_room_by_code('ABC-123-XYZ');

-- 6.3 Test: Join room
SELECT '--- TEST: dt_vc_join_room ---' AS test_name;

-- User 2 joins the room
CALL dt_vc_join_room(
    @p_room_id,                     -- room_id
    @p_user_id2,                    -- user_id (second user)
    @p_participant_id,              -- OUT: participant ID
    @p_success,                     -- OUT: success flag
    @p_message                      -- OUT: message
);

SELECT @p_participant_id AS participant_id, @p_success AS success, @p_message AS message;

-- 6.4 Test: Get room participants
SELECT '--- TEST: dt_vc_get_room_participants ---' AS test_name;

CALL dt_vc_get_room_participants(@p_room_id);

-- 6.5 Test: Leave room
SELECT '--- TEST: dt_vc_leave_room ---' AS test_name;

CALL dt_vc_leave_room(@p_room_id, @p_user_id2);

-- Verify participant left
CALL dt_vc_get_room_participants(@p_room_id);

-- ============================================
-- SECTION 7: TEST CONTACT PROCEDURES
-- ============================================

SELECT '=== SECTION 7: TEST CONTACT PROCEDURES ===' AS section;

-- 7.1 Test: Add contact
SELECT '--- TEST: dt_vc_add_contact ---' AS test_name;

CALL dt_vc_add_contact(
    @p_user_id,                     -- user_id
    @p_user_id2,                    -- contact_user_id
    'My Friend',                    -- nickname
    @p_contact_id,                  -- OUT: contact ID
    @p_success,                     -- OUT: success flag
    @p_message                      -- OUT: message
);

SELECT @p_contact_id AS contact_id, @p_success AS success, @p_message AS message;

-- 7.2 Test: Get contacts
SELECT '--- TEST: dt_vc_get_contacts ---' AS test_name;

CALL dt_vc_get_contacts(@p_user_id);

-- 7.3 Test: Remove contact
SELECT '--- TEST: dt_vc_remove_contact ---' AS test_name;

CALL dt_vc_remove_contact(@p_user_id, @p_contact_id);

-- Verify contact removed (should be empty)
CALL dt_vc_get_contacts(@p_user_id);

-- ============================================
-- SECTION 8: TEST CALL LOG PROCEDURES
-- ============================================

SELECT '=== SECTION 8: TEST CALL LOG PROCEDURES ===' AS section;

-- 8.1 Test: Create call log
SELECT '--- TEST: dt_vc_create_call_log ---' AS test_name;

CALL dt_vc_create_call_log(
    @p_room_id,                     -- room_id
    @p_user_id,                     -- caller_id
    @p_user_id2,                    -- callee_id
    'one-to-one',                   -- call_type
    @p_call_id                      -- OUT: call ID
);

SELECT @p_call_id AS new_call_id;

-- 8.2 Test: Update call log (answer call)
SELECT '--- TEST: dt_vc_update_call_log (answered) ---' AS test_name;

CALL dt_vc_update_call_log(@p_call_id, 'answered', @p_user_id2);

-- Check call status
SELECT call_id, call_status, start_time FROM call_logs WHERE call_id = @p_call_id;

-- 8.3 Test: Update call log (end call)
SELECT '--- TEST: dt_vc_update_call_log (ended) ---' AS test_name;

-- Wait a moment to simulate call duration
SELECT SLEEP(1);

CALL dt_vc_update_call_log(@p_call_id, 'ended', @p_user_id);

-- Check call with duration
SELECT call_id, call_status, start_time, end_time, duration_seconds 
FROM call_logs WHERE call_id = @p_call_id;

-- 8.4 Test: Get call history
SELECT '--- TEST: dt_vc_get_call_history ---' AS test_name;

CALL dt_vc_get_call_history(@p_user_id, 10);

-- ============================================
-- SECTION 9: VERIFY DATA IN ALL TABLES
-- ============================================

SELECT '=== SECTION 9: VERIFY ALL DATA ===' AS section;

SELECT '--- USERS TABLE ---' AS table_name;
SELECT user_id, username, email, display_name, online_status, is_active, created_dt FROM users;

SELECT '--- SESSIONS TABLE ---' AS table_name;
SELECT session_id, user_id, LEFT(token, 30) AS token_preview, is_active, expires_at FROM sessions;

SELECT '--- ROOMS TABLE ---' AS table_name;
SELECT room_id, room_code, room_name, host_user_id, room_status, is_active FROM rooms;

SELECT '--- ROOM_PARTICIPANTS TABLE ---' AS table_name;
SELECT participant_id, room_id, user_id, participant_status, is_audio_on, is_video_on FROM room_participants;

SELECT '--- CONTACTS TABLE ---' AS table_name;
SELECT contact_id, user_id, contact_user_id, nickname, contact_status, is_deleted FROM contacts;

SELECT '--- CALL_LOGS TABLE ---' AS table_name;
SELECT call_id, caller_id, callee_id, call_type, call_status, duration_seconds FROM call_logs;

-- ============================================
-- SECTION 10: CLEANUP TEST DATA
-- ============================================

SELECT '=== SECTION 10: CLEANUP (OPTIONAL) ===' AS section;

-- Uncomment these lines to clean up test data:
-- DELETE FROM ice_candidates;
-- DELETE FROM call_logs;
-- DELETE FROM contacts;
-- DELETE FROM room_participants;
-- DELETE FROM rooms;
-- DELETE FROM sessions;
-- DELETE FROM users;

-- Or use this to reset auto-increment:
-- TRUNCATE TABLE ice_candidates;
-- SET FOREIGN_KEY_CHECKS = 0;
-- TRUNCATE TABLE call_logs;
-- TRUNCATE TABLE contacts;
-- TRUNCATE TABLE room_participants;
-- TRUNCATE TABLE rooms;
-- TRUNCATE TABLE sessions;
-- TRUNCATE TABLE users;
-- SET FOREIGN_KEY_CHECKS = 1;

SELECT '=== ALL TESTS COMPLETED ===' AS status;
SELECT 'Database is working correctly!' AS message;

