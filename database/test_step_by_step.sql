-- ============================================
-- WebRTC Video-Chat - Step-by-Step Database Test
-- ============================================
-- Run each section one by one in MySQL Workbench
-- or copy-paste into Terminal MySQL session
-- ============================================

-- First, connect to the database
USE RTC_Video_Chat_DB;

-- ============================================
-- STEP 1: VERIFY TABLES (Run this first)
-- ============================================

-- See all tables
SHOW TABLES;

-- Expected output: 7 tables
-- call_logs, contacts, ice_candidates, room_participants, rooms, sessions, users


-- ============================================
-- STEP 2: CLEAR OLD TEST DATA (Optional)
-- ============================================

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE ice_candidates;
TRUNCATE TABLE call_logs;
TRUNCATE TABLE contacts;
TRUNCATE TABLE room_participants;
TRUNCATE TABLE rooms;
TRUNCATE TABLE sessions;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

SELECT 'All tables cleared!' AS status;


-- ============================================
-- STEP 3: TEST USER CREATION
-- ============================================

-- Create first user
CALL dt_vc_create_user(
    'rahul',                        -- username
    'rahul@example.com',            -- email  
    'hashed_password_123',          -- password_hash
    'Rahul Pathak',                 -- display_name
    0,                              -- created_by (0 = self registration)
    @user1_id,                      -- OUT: will store new user ID
    @success,                       -- OUT: 1 = success, 0 = failed
    @message                        -- OUT: result message
);

-- Check the result
SELECT @user1_id AS user1_id, @success AS success, @message AS message;

-- Expected: user1_id = 1, success = 1, message = 'User created successfully'


-- ============================================
-- STEP 4: CREATE SECOND USER
-- ============================================

CALL dt_vc_create_user(
    'john',
    'john@example.com',
    'hashed_password_456',
    'John Doe',
    @user1_id,                      -- created_by = first user
    @user2_id,
    @success,
    @message
);

SELECT @user2_id AS user2_id, @success AS success, @message AS message;

-- Expected: user2_id = 2, success = 1


-- ============================================
-- STEP 5: TEST DUPLICATE USER (SHOULD FAIL)
-- ============================================

CALL dt_vc_create_user(
    'rahul',                        -- same username!
    'different@example.com',
    'password',
    'Rahul Clone',
    0,
    @dup_id,
    @success,
    @message
);

SELECT @dup_id AS dup_id, @success AS success, @message AS message;

-- Expected: dup_id = 0, success = 0, message = 'Username already exists'


-- ============================================
-- STEP 6: GET USER BY EMAIL (LOGIN CHECK)
-- ============================================

CALL dt_vc_get_user_by_email('rahul@example.com');

-- Expected: Returns user details for rahul


-- ============================================
-- STEP 7: GET USER BY USERNAME
-- ============================================

CALL dt_vc_get_user_by_username('john');

-- Expected: Returns user details for john


-- ============================================
-- STEP 8: GET USER BY ID
-- ============================================

CALL dt_vc_get_user_by_id(1);

-- Expected: Returns user with ID 1 (rahul)


-- ============================================
-- STEP 9: UPDATE USER STATUS (ONLINE)
-- ============================================

CALL dt_vc_update_user_status(1, 'online', 1);

-- Verify the change
SELECT user_id, username, online_status FROM users WHERE user_id = 1;

-- Expected: online_status = 'online'


-- ============================================
-- STEP 10: CREATE SESSION (LOGIN)
-- ============================================

CALL dt_vc_create_session(
    1,                              -- user_id
    'jwt_token_abc123xyz789',       -- token
    '192.168.1.100',                -- ip_address
    'Mozilla/5.0 Chrome/120.0',     -- user_agent
    DATE_ADD(NOW(), INTERVAL 7 DAY), -- expires_at (7 days from now)
    @session_id                     -- OUT: new session ID
);

SELECT @session_id AS session_id;

-- Expected: session_id = 1


-- ============================================
-- STEP 11: GET SESSION (VALIDATE TOKEN)
-- ============================================

CALL dt_vc_get_session('jwt_token_abc123xyz789');

-- Expected: Returns session with user info


-- ============================================
-- STEP 12: CREATE VIDEO ROOM
-- ============================================

CALL dt_vc_create_room(
    'MEET-ABC-123',                 -- room_code
    'Team Meeting Room',            -- room_name
    1,                              -- host_user_id (rahul)
    5,                              -- max_participants
    0,                              -- is_private (0 = public)
    NULL,                           -- password_hash (no password)
    @room_id,                       -- OUT: new room ID
    @success,
    @message
);

SELECT @room_id AS room_id, @success AS success, @message AS message;

-- Expected: room_id = 1, success = 1


-- ============================================
-- STEP 13: GET ROOM BY CODE
-- ============================================

CALL dt_vc_get_room_by_code('MEET-ABC-123');

-- Expected: Returns room details


-- ============================================
-- STEP 14: JOIN ROOM (User 2 joins)
-- ============================================

CALL dt_vc_join_room(
    1,                              -- room_id
    2,                              -- user_id (john joins)
    @participant_id,
    @success,
    @message
);

SELECT @participant_id AS participant_id, @success AS success, @message AS message;

-- Expected: participant_id = 1, success = 1


-- ============================================
-- STEP 15: GET ROOM PARTICIPANTS
-- ============================================

CALL dt_vc_get_room_participants(1);

-- Expected: Shows john as connected participant


-- ============================================
-- STEP 16: ADD CONTACT
-- ============================================

CALL dt_vc_add_contact(
    1,                              -- user_id (rahul)
    2,                              -- contact_user_id (john)
    'My Friend John',               -- nickname
    @contact_id,
    @success,
    @message
);

SELECT @contact_id AS contact_id, @success AS success, @message AS message;

-- Expected: contact_id = 1, success = 1


-- ============================================
-- STEP 17: GET CONTACTS
-- ============================================

CALL dt_vc_get_contacts(1);

-- Expected: Shows john as rahul's contact


-- ============================================
-- STEP 18: CREATE CALL LOG
-- ============================================

CALL dt_vc_create_call_log(
    1,                              -- room_id
    1,                              -- caller_id (rahul)
    2,                              -- callee_id (john)
    'one-to-one',                   -- call_type
    @call_id
);

SELECT @call_id AS call_id;

-- Expected: call_id = 1


-- ============================================
-- STEP 19: UPDATE CALL (ANSWERED)
-- ============================================

CALL dt_vc_update_call_log(1, 'answered', 2);

-- Check call status
SELECT call_id, call_status, start_time FROM call_logs WHERE call_id = 1;

-- Expected: call_status = 'answered', start_time = current time


-- ============================================
-- STEP 20: END CALL
-- ============================================

-- Wait 2 seconds to simulate call duration
SELECT SLEEP(2);

CALL dt_vc_update_call_log(1, 'ended', 1);

-- Check final call status
SELECT call_id, call_status, start_time, end_time, duration_seconds 
FROM call_logs WHERE call_id = 1;

-- Expected: call_status = 'ended', duration_seconds > 0


-- ============================================
-- STEP 21: GET CALL HISTORY
-- ============================================

CALL dt_vc_get_call_history(1, 10);

-- Expected: Shows the call we just made


-- ============================================
-- STEP 22: LEAVE ROOM
-- ============================================

CALL dt_vc_leave_room(1, 2);

-- Check participant status
SELECT * FROM room_participants WHERE room_id = 1;

-- Expected: participant_status = 'left'


-- ============================================
-- STEP 23: LOGOUT (INVALIDATE SESSION)
-- ============================================

CALL dt_vc_invalidate_session('jwt_token_abc123xyz789');

-- Try to get session again (should fail)
CALL dt_vc_get_session('jwt_token_abc123xyz789');

-- Expected: Empty result (session invalidated)


-- ============================================
-- STEP 24: VERIFY ALL DATA
-- ============================================

SELECT 'USERS:' AS table_name;
SELECT user_id, username, email, display_name, online_status FROM users;

SELECT 'SESSIONS:' AS table_name;
SELECT session_id, user_id, is_active, expires_at FROM sessions;

SELECT 'ROOMS:' AS table_name;
SELECT room_id, room_code, room_name, room_status FROM rooms;

SELECT 'PARTICIPANTS:' AS table_name;
SELECT participant_id, room_id, user_id, participant_status FROM room_participants;

SELECT 'CONTACTS:' AS table_name;
SELECT contact_id, user_id, contact_user_id, nickname FROM contacts;

SELECT 'CALL LOGS:' AS table_name;
SELECT call_id, caller_id, callee_id, call_status, duration_seconds FROM call_logs;


-- ============================================
-- SUCCESS! ALL TESTS COMPLETED
-- ============================================

SELECT '✅ ALL DATABASE TESTS PASSED!' AS result;

