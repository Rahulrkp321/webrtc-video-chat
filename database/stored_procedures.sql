-- ============================================
-- WebRTC Video-Chat Stored Procedures
-- ============================================
-- All stored procedures are prefixed with 'dt_vc_'
-- ALL database access MUST use these procedures
-- No inline SQL allowed in the application!
-- ============================================

USE RTC_Video_Chat_DB;

-- ============================================
-- USER MANAGEMENT PROCEDURES
-- ============================================

-- Drop existing procedures if they exist
DROP PROCEDURE IF EXISTS dt_vc_create_user;
DROP PROCEDURE IF EXISTS dt_vc_get_user_by_email;
DROP PROCEDURE IF EXISTS dt_vc_get_user_by_username;
DROP PROCEDURE IF EXISTS dt_vc_get_user_by_id;
DROP PROCEDURE IF EXISTS dt_vc_update_user_status;
DROP PROCEDURE IF EXISTS dt_vc_update_user_profile;


-- ============================================
-- PROCEDURE: dt_vc_create_user
-- ============================================
-- Creates a new user account
-- Parameters:
--   IN  p_username: Unique username
--   IN  p_email: Unique email address
--   IN  p_password_hash: Hashed password
--   IN  p_display_name: Display name (optional)
--   IN  p_created_by: User ID who created (0 for self)
--   OUT p_user_id: The new user's ID
--   OUT p_success: 1 if success, 0 if failed
--   OUT p_message: Result message
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_create_user(
    IN  p_username      VARCHAR(50),
    IN  p_email         VARCHAR(100),
    IN  p_password_hash VARCHAR(255),
    IN  p_display_name  VARCHAR(100),
    IN  p_created_by    INT,
    OUT p_user_id       INT,
    OUT p_success       TINYINT,
    OUT p_message       VARCHAR(255)
)
BEGIN
    DECLARE v_existing_count INT DEFAULT 0;
    
    -- Initialize output
    SET p_user_id = 0;
    SET p_success = 0;
    SET p_message = '';
    
    -- Check if username already exists
    SELECT COUNT(*) INTO v_existing_count
    FROM users
    WHERE username = p_username AND is_deleted = 0;
    
    IF v_existing_count > 0 THEN
        SET p_message = 'Username already exists';
    ELSE
        -- Check if email already exists
        SELECT COUNT(*) INTO v_existing_count
        FROM users
        WHERE email = p_email AND is_deleted = 0;
        
        IF v_existing_count > 0 THEN
            SET p_message = 'Email already exists';
        ELSE
            -- Create the user
            INSERT INTO users (
                username,
                email,
                password_hash,
                display_name,
                is_active,
                is_deleted,
                created_dt,
                created_by
            ) VALUES (
                p_username,
                p_email,
                p_password_hash,
                IFNULL(p_display_name, p_username),
                1,
                0,
                NOW(),
                p_created_by
            );
            
            SET p_user_id = LAST_INSERT_ID();
            SET p_success = 1;
            SET p_message = 'User created successfully';
        END IF;
    END IF;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_user_by_email
-- ============================================
-- Gets user by email address (for login)
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_user_by_email(
    IN p_email VARCHAR(100)
)
BEGIN
    SELECT 
        user_id,
        username,
        email,
        password_hash,
        display_name,
        avatar_url,
        online_status,
        last_seen,
        is_active,
        created_dt
    FROM users
    WHERE email = p_email
      AND is_deleted = 0;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_user_by_username
-- ============================================
-- Gets user by username
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_user_by_username(
    IN p_username VARCHAR(50)
)
BEGIN
    SELECT 
        user_id,
        username,
        email,
        password_hash,
        display_name,
        avatar_url,
        online_status,
        last_seen,
        is_active,
        created_dt
    FROM users
    WHERE username = p_username
      AND is_deleted = 0;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_user_by_id
-- ============================================
-- Gets user by ID
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_user_by_id(
    IN p_user_id INT
)
BEGIN
    SELECT 
        user_id,
        username,
        email,
        display_name,
        avatar_url,
        online_status,
        last_seen,
        is_active,
        created_dt
    FROM users
    WHERE user_id = p_user_id
      AND is_deleted = 0;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_update_user_status
-- ============================================
-- Updates user online status
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_update_user_status(
    IN p_user_id       INT,
    IN p_online_status ENUM('online', 'offline', 'busy', 'away'),
    IN p_updated_by    INT
)
BEGIN
    UPDATE users
    SET 
        online_status = p_online_status,
        last_seen = IF(p_online_status = 'offline', NOW(), last_seen),
        updated_dt = NOW(),
        updated_by = p_updated_by
    WHERE user_id = p_user_id
      AND is_deleted = 0;
      
    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;


-- ============================================
-- SESSION MANAGEMENT PROCEDURES
-- ============================================

DROP PROCEDURE IF EXISTS dt_vc_create_session;
DROP PROCEDURE IF EXISTS dt_vc_get_session;
DROP PROCEDURE IF EXISTS dt_vc_invalidate_session;
DROP PROCEDURE IF EXISTS dt_vc_cleanup_expired_sessions;


-- ============================================
-- PROCEDURE: dt_vc_create_session
-- ============================================
-- Creates a new user session (login)
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_create_session(
    IN  p_user_id    INT,
    IN  p_token      VARCHAR(500),
    IN  p_ip_address VARCHAR(45),
    IN  p_user_agent VARCHAR(500),
    IN  p_expires_at DATETIME,
    OUT p_session_id INT
)
BEGIN
    INSERT INTO sessions (
        user_id,
        token,
        ip_address,
        user_agent,
        expires_at,
        is_active,
        is_deleted,
        created_dt,
        created_by
    ) VALUES (
        p_user_id,
        p_token,
        p_ip_address,
        p_user_agent,
        p_expires_at,
        1,
        0,
        NOW(),
        p_user_id
    );
    
    SET p_session_id = LAST_INSERT_ID();
    
    -- Update user status to online
    UPDATE users
    SET online_status = 'online', updated_dt = NOW()
    WHERE user_id = p_user_id;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_session
-- ============================================
-- Gets session by token (for authentication)
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_session(
    IN p_token VARCHAR(500)
)
BEGIN
    SELECT 
        s.session_id,
        s.user_id,
        s.token,
        s.expires_at,
        s.is_active,
        u.username,
        u.email,
        u.display_name,
        u.avatar_url
    FROM sessions s
    INNER JOIN users u ON s.user_id = u.user_id
    WHERE s.token = p_token
      AND s.is_active = 1
      AND s.is_deleted = 0
      AND s.expires_at > NOW()
      AND u.is_active = 1
      AND u.is_deleted = 0;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_invalidate_session
-- ============================================
-- Invalidates a session (logout)
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_invalidate_session(
    IN p_token VARCHAR(500)
)
BEGIN
    DECLARE v_user_id INT;
    
    -- Get user ID before invalidating
    SELECT user_id INTO v_user_id
    FROM sessions
    WHERE token = p_token AND is_active = 1;
    
    -- Invalidate the session
    UPDATE sessions
    SET 
        is_active = 0,
        updated_dt = NOW()
    WHERE token = p_token;
    
    -- Update user status to offline if this was their only active session
    IF v_user_id IS NOT NULL THEN
        UPDATE users
        SET 
            online_status = 'offline',
            last_seen = NOW()
        WHERE user_id = v_user_id
          AND NOT EXISTS (
              SELECT 1 FROM sessions 
              WHERE user_id = v_user_id 
                AND is_active = 1 
                AND expires_at > NOW()
          );
    END IF;
    
    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;


-- ============================================
-- ROOM MANAGEMENT PROCEDURES
-- ============================================

DROP PROCEDURE IF EXISTS dt_vc_create_room;
DROP PROCEDURE IF EXISTS dt_vc_get_room_by_code;
DROP PROCEDURE IF EXISTS dt_vc_update_room_status;
DROP PROCEDURE IF EXISTS dt_vc_join_room;
DROP PROCEDURE IF EXISTS dt_vc_leave_room;
DROP PROCEDURE IF EXISTS dt_vc_get_room_participants;


-- ============================================
-- PROCEDURE: dt_vc_create_room
-- ============================================
-- Creates a new video chat room
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_create_room(
    IN  p_room_code       VARCHAR(20),
    IN  p_room_name       VARCHAR(100),
    IN  p_host_user_id    INT,
    IN  p_max_participants INT,
    IN  p_is_private      TINYINT,
    IN  p_password_hash   VARCHAR(255),
    OUT p_room_id         INT,
    OUT p_success         TINYINT,
    OUT p_message         VARCHAR(255)
)
BEGIN
    DECLARE v_existing_count INT DEFAULT 0;
    
    SET p_room_id = 0;
    SET p_success = 0;
    
    -- Check if room code already exists (active)
    SELECT COUNT(*) INTO v_existing_count
    FROM rooms
    WHERE room_code = p_room_code
      AND room_status IN ('waiting', 'active')
      AND is_deleted = 0;
    
    IF v_existing_count > 0 THEN
        SET p_message = 'Room code already in use';
    ELSE
        INSERT INTO rooms (
            room_code,
            room_name,
            host_user_id,
            max_participants,
            is_private,
            password_hash,
            room_status,
            is_active,
            is_deleted,
            created_dt,
            created_by
        ) VALUES (
            p_room_code,
            IFNULL(p_room_name, CONCAT('Room ', p_room_code)),
            p_host_user_id,
            IFNULL(p_max_participants, 10),
            IFNULL(p_is_private, 0),
            p_password_hash,
            'waiting',
            1,
            0,
            NOW(),
            p_host_user_id
        );
        
        SET p_room_id = LAST_INSERT_ID();
        SET p_success = 1;
        SET p_message = 'Room created successfully';
    END IF;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_room_by_code
-- ============================================
-- Gets room details by room code
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_room_by_code(
    IN p_room_code VARCHAR(20)
)
BEGIN
    SELECT 
        r.room_id,
        r.room_code,
        r.room_name,
        r.host_user_id,
        u.display_name AS host_name,
        r.max_participants,
        r.is_private,
        r.room_status,
        r.started_at,
        r.created_dt,
        (SELECT COUNT(*) FROM room_participants rp 
         WHERE rp.room_id = r.room_id AND rp.participant_status = 'connected') AS current_participants
    FROM rooms r
    INNER JOIN users u ON r.host_user_id = u.user_id
    WHERE r.room_code = p_room_code
      AND r.is_deleted = 0;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_join_room
-- ============================================
-- Adds a user to a room
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_join_room(
    IN  p_room_id    INT,
    IN  p_user_id    INT,
    OUT p_participant_id INT,
    OUT p_success    TINYINT,
    OUT p_message    VARCHAR(255)
)
BEGIN
    DECLARE v_max_participants INT;
    DECLARE v_current_count INT;
    DECLARE v_room_status VARCHAR(20);
    
    SET p_participant_id = 0;
    SET p_success = 0;
    
    -- Get room info
    SELECT max_participants, room_status 
    INTO v_max_participants, v_room_status
    FROM rooms
    WHERE room_id = p_room_id AND is_deleted = 0;
    
    IF v_room_status IS NULL THEN
        SET p_message = 'Room not found';
    ELSEIF v_room_status = 'ended' THEN
        SET p_message = 'Room has ended';
    ELSE
        -- Get current participant count
        SELECT COUNT(*) INTO v_current_count
        FROM room_participants
        WHERE room_id = p_room_id
          AND participant_status = 'connected'
          AND is_deleted = 0;
        
        IF v_current_count >= v_max_participants THEN
            SET p_message = 'Room is full';
        ELSE
            -- Check if user already in room
            SELECT participant_id INTO p_participant_id
            FROM room_participants
            WHERE room_id = p_room_id
              AND user_id = p_user_id
              AND participant_status = 'connected';
            
            IF p_participant_id > 0 THEN
                SET p_success = 1;
                SET p_message = 'Already in room';
            ELSE
                -- Add participant
                INSERT INTO room_participants (
                    room_id,
                    user_id,
                    join_time,
                    participant_status,
                    is_active,
                    is_deleted,
                    created_dt,
                    created_by
                ) VALUES (
                    p_room_id,
                    p_user_id,
                    NOW(),
                    'connected',
                    1,
                    0,
                    NOW(),
                    p_user_id
                );
                
                SET p_participant_id = LAST_INSERT_ID();
                SET p_success = 1;
                SET p_message = 'Joined room successfully';
                
                -- Update room status to active if first join after host
                UPDATE rooms
                SET room_status = 'active', started_at = IFNULL(started_at, NOW())
                WHERE room_id = p_room_id AND room_status = 'waiting';
            END IF;
        END IF;
    END IF;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_leave_room
-- ============================================
-- Removes a user from a room
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_leave_room(
    IN p_room_id INT,
    IN p_user_id INT
)
BEGIN
    -- Update participant status
    UPDATE room_participants
    SET 
        participant_status = 'left',
        leave_time = NOW(),
        updated_dt = NOW(),
        updated_by = p_user_id
    WHERE room_id = p_room_id
      AND user_id = p_user_id
      AND participant_status = 'connected';
    
    -- Check if room is empty and end it
    UPDATE rooms r
    SET 
        room_status = 'ended',
        ended_at = NOW(),
        updated_dt = NOW()
    WHERE r.room_id = p_room_id
      AND NOT EXISTS (
          SELECT 1 FROM room_participants rp
          WHERE rp.room_id = r.room_id
            AND rp.participant_status = 'connected'
      );
    
    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_room_participants
-- ============================================
-- Gets all participants in a room
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_room_participants(
    IN p_room_id INT
)
BEGIN
    SELECT 
        rp.participant_id,
        rp.user_id,
        u.username,
        u.display_name,
        u.avatar_url,
        rp.join_time,
        rp.participant_status,
        rp.is_audio_on,
        rp.is_video_on,
        rp.is_screen_sharing
    FROM room_participants rp
    INNER JOIN users u ON rp.user_id = u.user_id
    WHERE rp.room_id = p_room_id
      AND rp.participant_status = 'connected'
      AND rp.is_deleted = 0
    ORDER BY rp.join_time ASC;
END //

DELIMITER ;


-- ============================================
-- CONTACT MANAGEMENT PROCEDURES
-- ============================================

DROP PROCEDURE IF EXISTS dt_vc_add_contact;
DROP PROCEDURE IF EXISTS dt_vc_get_contacts;
DROP PROCEDURE IF EXISTS dt_vc_remove_contact;


-- ============================================
-- PROCEDURE: dt_vc_add_contact
-- ============================================
-- Adds a user to contacts list
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_add_contact(
    IN  p_user_id         INT,
    IN  p_contact_user_id INT,
    IN  p_nickname        VARCHAR(100),
    OUT p_contact_id      INT,
    OUT p_success         TINYINT,
    OUT p_message         VARCHAR(255)
)
BEGIN
    DECLARE v_existing_count INT DEFAULT 0;
    
    SET p_contact_id = 0;
    SET p_success = 0;
    
    IF p_user_id = p_contact_user_id THEN
        SET p_message = 'Cannot add yourself as contact';
    ELSE
        -- Check if contact already exists
        SELECT COUNT(*) INTO v_existing_count
        FROM contacts
        WHERE user_id = p_user_id
          AND contact_user_id = p_contact_user_id
          AND is_deleted = 0;
        
        IF v_existing_count > 0 THEN
            SET p_message = 'Contact already exists';
        ELSE
            INSERT INTO contacts (
                user_id,
                contact_user_id,
                nickname,
                contact_status,
                is_active,
                is_deleted,
                created_dt,
                created_by
            ) VALUES (
                p_user_id,
                p_contact_user_id,
                p_nickname,
                'accepted',
                1,
                0,
                NOW(),
                p_user_id
            );
            
            SET p_contact_id = LAST_INSERT_ID();
            SET p_success = 1;
            SET p_message = 'Contact added successfully';
        END IF;
    END IF;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_contacts
-- ============================================
-- Gets all contacts for a user
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_contacts(
    IN p_user_id INT
)
BEGIN
    SELECT 
        c.contact_id,
        c.contact_user_id AS user_id,
        u.username,
        IFNULL(c.nickname, u.display_name) AS display_name,
        u.avatar_url,
        u.online_status,
        u.last_seen,
        c.contact_status
    FROM contacts c
    INNER JOIN users u ON c.contact_user_id = u.user_id
    WHERE c.user_id = p_user_id
      AND c.is_deleted = 0
      AND u.is_deleted = 0
    ORDER BY u.online_status = 'online' DESC, u.display_name ASC;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_remove_contact
-- ============================================
-- Removes a contact (soft delete)
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_remove_contact(
    IN p_user_id    INT,
    IN p_contact_id INT
)
BEGIN
    UPDATE contacts
    SET 
        is_deleted = 1,
        updated_dt = NOW(),
        updated_by = p_user_id
    WHERE contact_id = p_contact_id
      AND user_id = p_user_id;
    
    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;


-- ============================================
-- CALL LOG PROCEDURES
-- ============================================

DROP PROCEDURE IF EXISTS dt_vc_create_call_log;
DROP PROCEDURE IF EXISTS dt_vc_update_call_log;
DROP PROCEDURE IF EXISTS dt_vc_get_call_history;


-- ============================================
-- PROCEDURE: dt_vc_create_call_log
-- ============================================
-- Creates a new call log entry
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_create_call_log(
    IN  p_room_id     INT,
    IN  p_caller_id   INT,
    IN  p_callee_id   INT,
    IN  p_call_type   ENUM('one-to-one', 'group'),
    OUT p_call_id     INT
)
BEGIN
    INSERT INTO call_logs (
        room_id,
        caller_id,
        callee_id,
        call_type,
        call_status,
        is_active,
        is_deleted,
        created_dt,
        created_by
    ) VALUES (
        p_room_id,
        p_caller_id,
        p_callee_id,
        IFNULL(p_call_type, 'one-to-one'),
        'initiated',
        1,
        0,
        NOW(),
        p_caller_id
    );
    
    SET p_call_id = LAST_INSERT_ID();
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_update_call_log
-- ============================================
-- Updates call log status
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_update_call_log(
    IN p_call_id     INT,
    IN p_call_status ENUM('initiated', 'ringing', 'answered', 'rejected', 'missed', 'ended'),
    IN p_updated_by  INT
)
BEGIN
    UPDATE call_logs
    SET 
        call_status = p_call_status,
        start_time = IF(p_call_status = 'answered' AND start_time IS NULL, NOW(), start_time),
        end_time = IF(p_call_status = 'ended', NOW(), end_time),
        duration_seconds = IF(p_call_status = 'ended' AND start_time IS NOT NULL, 
                              TIMESTAMPDIFF(SECOND, start_time, NOW()), duration_seconds),
        updated_dt = NOW(),
        updated_by = p_updated_by
    WHERE call_id = p_call_id;
    
    SELECT ROW_COUNT() AS affected_rows;
END //

DELIMITER ;


-- ============================================
-- PROCEDURE: dt_vc_get_call_history
-- ============================================
-- Gets call history for a user
-- ============================================

DELIMITER //

CREATE PROCEDURE dt_vc_get_call_history(
    IN p_user_id INT,
    IN p_limit   INT
)
BEGIN
    SET p_limit = IFNULL(p_limit, 50);
    
    SELECT 
        cl.call_id,
        cl.room_id,
        cl.caller_id,
        caller.display_name AS caller_name,
        cl.callee_id,
        callee.display_name AS callee_name,
        cl.call_type,
        cl.call_status,
        cl.start_time,
        cl.end_time,
        cl.duration_seconds,
        cl.created_dt,
        CASE 
            WHEN cl.caller_id = p_user_id THEN 'outgoing'
            ELSE 'incoming'
        END AS direction
    FROM call_logs cl
    INNER JOIN users caller ON cl.caller_id = caller.user_id
    LEFT JOIN users callee ON cl.callee_id = callee.user_id
    WHERE (cl.caller_id = p_user_id OR cl.callee_id = p_user_id)
      AND cl.is_deleted = 0
    ORDER BY cl.created_dt DESC
    LIMIT p_limit;
END //

DELIMITER ;


-- ============================================
-- VERIFICATION
-- ============================================
-- List all stored procedures

SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'RTC_Video_Chat_DB'
ORDER BY ROUTINE_NAME;

SELECT 'Stored procedures created successfully!' AS message;
