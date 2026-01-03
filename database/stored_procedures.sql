-- ============================================
-- WebRTC Video-Chat Stored Procedures
-- ============================================
-- ALL database access MUST go through these procedures
-- NO inline SQL allowed in application code!
--
-- NAMING CONVENTION: dt_vc_[action]_[entity]
-- - dt = data
-- - vc = video chat
-- - action = create, get, update, delete, etc.
-- - entity = user, room, call, contact, session
--
-- EXAMPLES:
-- - dt_vc_create_user
-- - dt_vc_get_user_by_email
-- - dt_vc_update_room
-- ============================================

USE RTC_Video_Chat_DB;

-- ============================================
-- Drop existing procedures (for re-running)
-- ============================================
DROP PROCEDURE IF EXISTS dt_vc_create_user;
DROP PROCEDURE IF EXISTS dt_vc_get_user_by_id;
DROP PROCEDURE IF EXISTS dt_vc_get_user_by_email;
DROP PROCEDURE IF EXISTS dt_vc_get_user_by_username;
DROP PROCEDURE IF EXISTS dt_vc_update_user;
DROP PROCEDURE IF EXISTS dt_vc_delete_user;
DROP PROCEDURE IF EXISTS dt_vc_update_user_online_status;
DROP PROCEDURE IF EXISTS dt_vc_search_users;
DROP PROCEDURE IF EXISTS dt_vc_create_room;
DROP PROCEDURE IF EXISTS dt_vc_get_room_by_id;
DROP PROCEDURE IF EXISTS dt_vc_get_room_by_code;
DROP PROCEDURE IF EXISTS dt_vc_get_user_rooms;
DROP PROCEDURE IF EXISTS dt_vc_update_room;
DROP PROCEDURE IF EXISTS dt_vc_delete_room;
DROP PROCEDURE IF EXISTS dt_vc_update_room_participants;
DROP PROCEDURE IF EXISTS dt_vc_create_call_log;
DROP PROCEDURE IF EXISTS dt_vc_update_call_log;
DROP PROCEDURE IF EXISTS dt_vc_get_user_call_history;
DROP PROCEDURE IF EXISTS dt_vc_add_contact;
DROP PROCEDURE IF EXISTS dt_vc_get_user_contacts;
DROP PROCEDURE IF EXISTS dt_vc_update_contact;
DROP PROCEDURE IF EXISTS dt_vc_delete_contact;
DROP PROCEDURE IF EXISTS dt_vc_create_session;
DROP PROCEDURE IF EXISTS dt_vc_validate_session;
DROP PROCEDURE IF EXISTS dt_vc_delete_session;
DROP PROCEDURE IF EXISTS dt_vc_cleanup_expired_sessions;
DROP PROCEDURE IF EXISTS dt_vc_add_room_participant;
DROP PROCEDURE IF EXISTS dt_vc_remove_room_participant;
DROP PROCEDURE IF EXISTS dt_vc_get_room_participants;


-- ============================================
-- USER STORED PROCEDURES
-- ============================================

-- ----------------------------------------
-- dt_vc_create_user
-- ----------------------------------------
-- PURPOSE: Register a new user
-- 
-- INPUT PARAMETERS:
--   p_username: Unique username
--   p_email: Unique email address
--   p_password_hash: Already hashed password (from bcrypt)
--   p_display_name: User's display name
--   p_created_by: ID of user creating this (NULL for self-registration)
--
-- OUTPUT PARAMETERS:
--   p_user_id: The new user's ID (or NULL if failed)
--   p_success: TRUE if successful, FALSE if failed
--   p_message: Description of what happened
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_create_user(
    IN p_username VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_password_hash VARCHAR(255),
    IN p_display_name VARCHAR(100),
    IN p_created_by INT,
    OUT p_user_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    -- Error handler: If any SQL error occurs, rollback and set error message
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
        SET p_user_id = NULL;
        ROLLBACK;
    END;
    
    -- Start transaction (all or nothing)
    START TRANSACTION;
    
    -- Check if username already exists
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'Username already exists';
        SET p_user_id = NULL;
    -- Check if email already exists
    ELSEIF EXISTS (SELECT 1 FROM users WHERE email = p_email AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'Email already exists';
        SET p_user_id = NULL;
    ELSE
        -- Insert the new user
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
            COALESCE(p_display_name, p_username),  -- Use username if no display name
            TRUE, 
            FALSE, 
            NOW(), 
            p_created_by
        );
        
        -- Get the new user's ID
        SET p_user_id = LAST_INSERT_ID();
        SET p_success = TRUE;
        SET p_message = 'User created successfully';
    END IF;
    
    COMMIT;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_user_by_id
-- ----------------------------------------
-- PURPOSE: Get user details by user_id
-- NOTE: Does NOT return password_hash (security)
-- ----------------------------------------

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
        is_online,
        last_seen,
        is_active,
        created_dt
    FROM users
    WHERE user_id = p_user_id 
      AND is_active = TRUE 
      AND is_deleted = FALSE;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_user_by_email
-- ----------------------------------------
-- PURPOSE: Get user by email (for login)
-- NOTE: INCLUDES password_hash for verification
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_get_user_by_email(
    IN p_email VARCHAR(100)
)
BEGIN
    SELECT 
        user_id,
        username,
        email,
        password_hash,  -- Included for login verification
        display_name,
        avatar_url,
        is_online,
        last_seen,
        is_active,
        created_dt
    FROM users
    WHERE email = p_email 
      AND is_active = TRUE 
      AND is_deleted = FALSE;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_user_by_username
-- ----------------------------------------
-- PURPOSE: Get user by username
-- ----------------------------------------

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
        is_online,
        last_seen,
        is_active,
        created_dt
    FROM users
    WHERE username = p_username 
      AND is_active = TRUE 
      AND is_deleted = FALSE;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_update_user
-- ----------------------------------------
-- PURPOSE: Update user profile
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_update_user(
    IN p_user_id INT,
    IN p_display_name VARCHAR(100),
    IN p_avatar_url VARCHAR(255),
    IN p_updated_by INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
    END;
    
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
    ELSE
        UPDATE users
        SET 
            display_name = COALESCE(p_display_name, display_name),
            avatar_url = COALESCE(p_avatar_url, avatar_url),
            updated_dt = NOW(),
            updated_by = p_updated_by
        WHERE user_id = p_user_id 
          AND is_deleted = FALSE;
        
        SET p_success = TRUE;
        SET p_message = 'User updated successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_delete_user
-- ----------------------------------------
-- PURPOSE: Soft delete a user
-- NOTE: Sets is_deleted = TRUE, doesn't actually delete
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_delete_user(
    IN p_user_id INT,
    IN p_deleted_by INT,
    IN p_remarks TEXT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
    END;
    
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
    ELSE
        UPDATE users
        SET 
            is_active = FALSE,
            is_deleted = TRUE,
            remarks = COALESCE(p_remarks, remarks),
            updated_dt = NOW(),
            updated_by = p_deleted_by
        WHERE user_id = p_user_id;
        
        SET p_success = TRUE;
        SET p_message = 'User deleted successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_update_user_online_status
-- ----------------------------------------
-- PURPOSE: Update user's online/offline status
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_update_user_online_status(
    IN p_user_id INT,
    IN p_is_online BOOLEAN
)
BEGIN
    UPDATE users
    SET 
        is_online = p_is_online,
        last_seen = NOW(),
        updated_dt = NOW()
    WHERE user_id = p_user_id 
      AND is_deleted = FALSE;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_search_users
-- ----------------------------------------
-- PURPOSE: Search for users by name/email
-- Used for: Finding people to add as contacts
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_search_users(
    IN p_search_term VARCHAR(100),
    IN p_exclude_user_id INT,
    IN p_limit INT
)
BEGIN
    SELECT 
        user_id,
        username,
        display_name,
        avatar_url,
        is_online,
        last_seen
    FROM users
    WHERE (
            username LIKE CONCAT('%', p_search_term, '%') 
            OR display_name LIKE CONCAT('%', p_search_term, '%')
            OR email LIKE CONCAT('%', p_search_term, '%')
          )
      AND (p_exclude_user_id IS NULL OR user_id != p_exclude_user_id)
      AND is_active = TRUE 
      AND is_deleted = FALSE
    LIMIT 10;
END //

DELIMITER ;


-- ============================================
-- ROOM STORED PROCEDURES
-- ============================================

-- ----------------------------------------
-- dt_vc_create_room
-- ----------------------------------------
-- PURPOSE: Create a new video chat room
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_create_room(
    IN p_room_code VARCHAR(20),
    IN p_room_name VARCHAR(100),
    IN p_owner_user_id INT,
    IN p_is_private BOOLEAN,
    IN p_password_hash VARCHAR(255),
    IN p_max_participants INT,
    IN p_created_by INT,
    OUT p_room_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
        SET p_room_id = NULL;
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Check if room code already exists
    IF EXISTS (SELECT 1 FROM rooms WHERE room_code = p_room_code AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'Room code already exists';
        SET p_room_id = NULL;
    ELSE
        INSERT INTO rooms (
            room_code,
            room_name,
            owner_user_id,
            is_private,
            password_hash,
            max_participants,
            current_participants,
            is_active,
            is_deleted,
            created_dt,
            created_by
        ) VALUES (
            p_room_code,
            COALESCE(p_room_name, CONCAT('Room ', p_room_code)),
            p_owner_user_id,
            COALESCE(p_is_private, FALSE),
            p_password_hash,
            COALESCE(p_max_participants, 10),
            0,
            TRUE,
            FALSE,
            NOW(),
            p_created_by
        );
        
        SET p_room_id = LAST_INSERT_ID();
        SET p_success = TRUE;
        SET p_message = 'Room created successfully';
    END IF;
    
    COMMIT;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_room_by_code
-- ----------------------------------------
-- PURPOSE: Get room details by room code
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_get_room_by_code(
    IN p_room_code VARCHAR(20)
)
BEGIN
    SELECT 
        r.room_id,
        r.room_code,
        r.room_name,
        r.owner_user_id,
        r.is_private,
        r.max_participants,
        r.current_participants,
        r.is_active,
        r.created_dt,
        u.username AS owner_username,
        u.display_name AS owner_display_name
    FROM rooms r
    LEFT JOIN users u ON r.owner_user_id = u.user_id
    WHERE r.room_code = p_room_code 
      AND r.is_active = TRUE 
      AND r.is_deleted = FALSE;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_room_by_id
-- ----------------------------------------
-- PURPOSE: Get room details by room_id
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_get_room_by_id(
    IN p_room_id INT
)
BEGIN
    SELECT 
        r.room_id,
        r.room_code,
        r.room_name,
        r.owner_user_id,
        r.is_private,
        r.password_hash,
        r.max_participants,
        r.current_participants,
        r.is_active,
        r.created_dt,
        u.username AS owner_username,
        u.display_name AS owner_display_name
    FROM rooms r
    LEFT JOIN users u ON r.owner_user_id = u.user_id
    WHERE r.room_id = p_room_id 
      AND r.is_active = TRUE 
      AND r.is_deleted = FALSE;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_user_rooms
-- ----------------------------------------
-- PURPOSE: Get all rooms created by a user
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_get_user_rooms(
    IN p_user_id INT
)
BEGIN
    SELECT 
        room_id,
        room_code,
        room_name,
        is_private,
        max_participants,
        current_participants,
        created_dt
    FROM rooms
    WHERE owner_user_id = p_user_id 
      AND is_active = TRUE 
      AND is_deleted = FALSE
    ORDER BY created_dt DESC;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_update_room
-- ----------------------------------------
-- PURPOSE: Update room details
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_update_room(
    IN p_room_id INT,
    IN p_room_name VARCHAR(100),
    IN p_is_private BOOLEAN,
    IN p_password_hash VARCHAR(255),
    IN p_max_participants INT,
    IN p_updated_by INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
    END;
    
    IF NOT EXISTS (SELECT 1 FROM rooms WHERE room_id = p_room_id AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'Room not found';
    ELSE
        UPDATE rooms
        SET 
            room_name = COALESCE(p_room_name, room_name),
            is_private = COALESCE(p_is_private, is_private),
            password_hash = COALESCE(p_password_hash, password_hash),
            max_participants = COALESCE(p_max_participants, max_participants),
            updated_dt = NOW(),
            updated_by = p_updated_by
        WHERE room_id = p_room_id 
          AND is_deleted = FALSE;
        
        SET p_success = TRUE;
        SET p_message = 'Room updated successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_delete_room
-- ----------------------------------------
-- PURPOSE: Soft delete a room
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_delete_room(
    IN p_room_id INT,
    IN p_deleted_by INT,
    IN p_remarks TEXT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM rooms WHERE room_id = p_room_id AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'Room not found';
    ELSE
        UPDATE rooms
        SET 
            is_active = FALSE,
            is_deleted = TRUE,
            remarks = COALESCE(p_remarks, remarks),
            updated_dt = NOW(),
            updated_by = p_deleted_by
        WHERE room_id = p_room_id;
        
        SET p_success = TRUE;
        SET p_message = 'Room deleted successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_update_room_participants
-- ----------------------------------------
-- PURPOSE: Update current participant count
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_update_room_participants(
    IN p_room_id INT,
    IN p_change INT  -- +1 for join, -1 for leave
)
BEGIN
    UPDATE rooms
    SET 
        current_participants = GREATEST(0, current_participants + p_change),
        updated_dt = NOW()
    WHERE room_id = p_room_id 
      AND is_deleted = FALSE;
END //

DELIMITER ;


-- ============================================
-- ROOM PARTICIPANT STORED PROCEDURES
-- ============================================

-- ----------------------------------------
-- dt_vc_add_room_participant
-- ----------------------------------------
-- PURPOSE: Add a user to a room
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_add_room_participant(
    IN p_room_id INT,
    IN p_user_id INT,
    IN p_is_host BOOLEAN,
    IN p_created_by INT,
    OUT p_participant_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_max_participants INT;
    DECLARE v_current_participants INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
        SET p_participant_id = NULL;
    END;
    
    -- Get room capacity
    SELECT max_participants, current_participants 
    INTO v_max_participants, v_current_participants
    FROM rooms 
    WHERE room_id = p_room_id AND is_deleted = FALSE;
    
    IF v_max_participants IS NULL THEN
        SET p_success = FALSE;
        SET p_message = 'Room not found';
        SET p_participant_id = NULL;
    ELSEIF v_current_participants >= v_max_participants THEN
        SET p_success = FALSE;
        SET p_message = 'Room is full';
        SET p_participant_id = NULL;
    ELSE
        -- Check if already in room
        IF EXISTS (
            SELECT 1 FROM room_participants 
            WHERE room_id = p_room_id AND user_id = p_user_id 
              AND left_at IS NULL AND is_deleted = FALSE
        ) THEN
            SET p_success = FALSE;
            SET p_message = 'User already in room';
            SET p_participant_id = NULL;
        ELSE
            -- Add participant
            INSERT INTO room_participants (
                room_id,
                user_id,
                joined_at,
                is_host,
                is_active,
                is_deleted,
                created_dt,
                created_by
            ) VALUES (
                p_room_id,
                p_user_id,
                NOW(),
                COALESCE(p_is_host, FALSE),
                TRUE,
                FALSE,
                NOW(),
                p_created_by
            );
            
            SET p_participant_id = LAST_INSERT_ID();
            
            -- Update room participant count
            CALL dt_vc_update_room_participants(p_room_id, 1);
            
            SET p_success = TRUE;
            SET p_message = 'Joined room successfully';
        END IF;
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_remove_room_participant
-- ----------------------------------------
-- PURPOSE: Remove a user from a room
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_remove_room_participant(
    IN p_room_id INT,
    IN p_user_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM room_participants 
        WHERE room_id = p_room_id AND user_id = p_user_id 
          AND left_at IS NULL AND is_deleted = FALSE
    ) THEN
        SET p_success = FALSE;
        SET p_message = 'User not in room';
    ELSE
        -- Mark as left
        UPDATE room_participants
        SET 
            left_at = NOW(),
            is_active = FALSE,
            updated_dt = NOW()
        WHERE room_id = p_room_id 
          AND user_id = p_user_id 
          AND left_at IS NULL;
        
        -- Update room participant count
        CALL dt_vc_update_room_participants(p_room_id, -1);
        
        SET p_success = TRUE;
        SET p_message = 'Left room successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_room_participants
-- ----------------------------------------
-- PURPOSE: Get all current participants in a room
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_get_room_participants(
    IN p_room_id INT
)
BEGIN
    SELECT 
        rp.participant_id,
        rp.user_id,
        rp.joined_at,
        rp.is_host,
        rp.is_muted,
        rp.is_video_off,
        u.username,
        u.display_name,
        u.avatar_url
    FROM room_participants rp
    JOIN users u ON rp.user_id = u.user_id
    WHERE rp.room_id = p_room_id 
      AND rp.left_at IS NULL 
      AND rp.is_active = TRUE 
      AND rp.is_deleted = FALSE
    ORDER BY rp.is_host DESC, rp.joined_at ASC;
END //

DELIMITER ;


-- ============================================
-- CALL LOG STORED PROCEDURES
-- ============================================

-- ----------------------------------------
-- dt_vc_create_call_log
-- ----------------------------------------
-- PURPOSE: Log a new call
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_create_call_log(
    IN p_room_id INT,
    IN p_caller_user_id INT,
    IN p_callee_user_id INT,
    IN p_created_by INT,
    OUT p_call_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
        SET p_call_id = NULL;
    END;
    
    INSERT INTO call_logs (
        room_id,
        caller_user_id,
        callee_user_id,
        started_at,
        call_status,
        is_active,
        is_deleted,
        created_dt,
        created_by
    ) VALUES (
        p_room_id,
        p_caller_user_id,
        p_callee_user_id,
        NOW(),
        'completed',
        TRUE,
        FALSE,
        NOW(),
        p_created_by
    );
    
    SET p_call_id = LAST_INSERT_ID();
    SET p_success = TRUE;
    SET p_message = 'Call log created successfully';
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_update_call_log
-- ----------------------------------------
-- PURPOSE: Update call when it ends
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_update_call_log(
    IN p_call_id INT,
    IN p_call_status ENUM('completed', 'missed', 'declined', 'failed'),
    IN p_updated_by INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_started_at DATETIME;
    
    IF NOT EXISTS (SELECT 1 FROM call_logs WHERE call_id = p_call_id AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'Call log not found';
    ELSE
        -- Get start time to calculate duration
        SELECT started_at INTO v_started_at 
        FROM call_logs 
        WHERE call_id = p_call_id;
        
        UPDATE call_logs
        SET 
            ended_at = NOW(),
            duration_seconds = TIMESTAMPDIFF(SECOND, v_started_at, NOW()),
            call_status = COALESCE(p_call_status, 'completed'),
            updated_dt = NOW(),
            updated_by = p_updated_by
        WHERE call_id = p_call_id;
        
        SET p_success = TRUE;
        SET p_message = 'Call log updated successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_user_call_history
-- ----------------------------------------
-- PURPOSE: Get call history for a user
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_get_user_call_history(
    IN p_user_id INT,
    IN p_limit INT,
    IN p_offset INT
)
BEGIN
    SELECT 
        c.call_id,
        c.room_id,
        c.started_at,
        c.ended_at,
        c.duration_seconds,
        c.call_status,
        r.room_code,
        r.room_name,
        caller.user_id AS caller_user_id,
        caller.username AS caller_username,
        caller.display_name AS caller_display_name,
        callee.user_id AS callee_user_id,
        callee.username AS callee_username,
        callee.display_name AS callee_display_name,
        -- Determine if user was caller or callee
        CASE 
            WHEN c.caller_user_id = p_user_id THEN 'outgoing'
            ELSE 'incoming'
        END AS call_direction
    FROM call_logs c
    LEFT JOIN rooms r ON c.room_id = r.room_id
    LEFT JOIN users caller ON c.caller_user_id = caller.user_id
    LEFT JOIN users callee ON c.callee_user_id = callee.user_id
    WHERE (c.caller_user_id = p_user_id OR c.callee_user_id = p_user_id)
      AND c.is_active = TRUE 
      AND c.is_deleted = FALSE
    ORDER BY c.started_at DESC
    LIMIT 20;
END //

DELIMITER ;


-- ============================================
-- CONTACT STORED PROCEDURES
-- ============================================

-- ----------------------------------------
-- dt_vc_add_contact
-- ----------------------------------------
-- PURPOSE: Add a contact to user's list
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_add_contact(
    IN p_user_id INT,
    IN p_contact_user_id INT,
    IN p_nickname VARCHAR(100),
    IN p_created_by INT,
    OUT p_contact_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
        SET p_contact_id = NULL;
    END;
    
    -- Can't add yourself
    IF p_user_id = p_contact_user_id THEN
        SET p_success = FALSE;
        SET p_message = 'Cannot add yourself as contact';
        SET p_contact_id = NULL;
    -- Check if contact user exists
    ELSEIF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_contact_user_id AND is_deleted = FALSE) THEN
        SET p_success = FALSE;
        SET p_message = 'User not found';
        SET p_contact_id = NULL;
    -- Check if already a contact
    ELSEIF EXISTS (
        SELECT 1 FROM contacts 
        WHERE user_id = p_user_id AND contact_user_id = p_contact_user_id AND is_deleted = FALSE
    ) THEN
        SET p_success = FALSE;
        SET p_message = 'Contact already exists';
        SET p_contact_id = NULL;
    ELSE
        INSERT INTO contacts (
            user_id,
            contact_user_id,
            nickname,
            is_active,
            is_deleted,
            created_dt,
            created_by
        ) VALUES (
            p_user_id,
            p_contact_user_id,
            p_nickname,
            TRUE,
            FALSE,
            NOW(),
            p_created_by
        );
        
        SET p_contact_id = LAST_INSERT_ID();
        SET p_success = TRUE;
        SET p_message = 'Contact added successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_get_user_contacts
-- ----------------------------------------
-- PURPOSE: Get all contacts for a user
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_get_user_contacts(
    IN p_user_id INT
)
BEGIN
    SELECT 
        c.contact_id,
        c.nickname,
        c.created_dt AS added_at,
        u.user_id,
        u.username,
        u.display_name,
        u.avatar_url,
        u.is_online,
        u.last_seen
    FROM contacts c
    JOIN users u ON c.contact_user_id = u.user_id
    WHERE c.user_id = p_user_id 
      AND c.is_active = TRUE 
      AND c.is_deleted = FALSE
      AND u.is_deleted = FALSE
    ORDER BY u.is_online DESC, u.display_name ASC;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_update_contact
-- ----------------------------------------
-- PURPOSE: Update contact nickname
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_update_contact(
    IN p_contact_id INT,
    IN p_user_id INT,
    IN p_nickname VARCHAR(100),
    IN p_updated_by INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM contacts 
        WHERE contact_id = p_contact_id AND user_id = p_user_id AND is_deleted = FALSE
    ) THEN
        SET p_success = FALSE;
        SET p_message = 'Contact not found';
    ELSE
        UPDATE contacts
        SET 
            nickname = p_nickname,
            updated_dt = NOW(),
            updated_by = p_updated_by
        WHERE contact_id = p_contact_id 
          AND user_id = p_user_id;
        
        SET p_success = TRUE;
        SET p_message = 'Contact updated successfully';
    END IF;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_delete_contact
-- ----------------------------------------
-- PURPOSE: Remove a contact (soft delete)
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_delete_contact(
    IN p_contact_id INT,
    IN p_user_id INT,
    IN p_deleted_by INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM contacts 
        WHERE contact_id = p_contact_id AND user_id = p_user_id AND is_deleted = FALSE
    ) THEN
        SET p_success = FALSE;
        SET p_message = 'Contact not found';
    ELSE
        UPDATE contacts
        SET 
            is_active = FALSE,
            is_deleted = TRUE,
            updated_dt = NOW(),
            updated_by = p_deleted_by
        WHERE contact_id = p_contact_id 
          AND user_id = p_user_id;
        
        SET p_success = TRUE;
        SET p_message = 'Contact removed successfully';
    END IF;
END //

DELIMITER ;


-- ============================================
-- SESSION STORED PROCEDURES
-- ============================================

-- ----------------------------------------
-- dt_vc_create_session
-- ----------------------------------------
-- PURPOSE: Create login session
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_create_session(
    IN p_user_id INT,
    IN p_token_hash VARCHAR(255),
    IN p_expires_at DATETIME,
    IN p_ip_address VARCHAR(45),
    IN p_user_agent VARCHAR(255),
    OUT p_session_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_success = FALSE;
        SET p_message = 'Database error occurred';
        SET p_session_id = NULL;
    END;
    
    INSERT INTO user_sessions (
        user_id,
        token_hash,
        expires_at,
        ip_address,
        user_agent,
        is_active,
        is_deleted,
        created_dt,
        created_by
    ) VALUES (
        p_user_id,
        p_token_hash,
        p_expires_at,
        p_ip_address,
        p_user_agent,
        TRUE,
        FALSE,
        NOW(),
        p_user_id
    );
    
    -- Update user online status
    CALL dt_vc_update_user_online_status(p_user_id, TRUE);
    
    SET p_session_id = LAST_INSERT_ID();
    SET p_success = TRUE;
    SET p_message = 'Session created successfully';
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_validate_session
-- ----------------------------------------
-- PURPOSE: Validate session token
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_validate_session(
    IN p_token_hash VARCHAR(255)
)
BEGIN
    SELECT 
        s.session_id,
        s.user_id,
        s.expires_at,
        u.username,
        u.email,
        u.display_name,
        u.avatar_url
    FROM user_sessions s
    JOIN users u ON s.user_id = u.user_id
    WHERE s.token_hash = p_token_hash 
      AND s.is_active = TRUE 
      AND s.is_deleted = FALSE
      AND s.expires_at > NOW()
      AND u.is_active = TRUE
      AND u.is_deleted = FALSE;
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_delete_session
-- ----------------------------------------
-- PURPOSE: Logout - invalidate session
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_delete_session(
    IN p_token_hash VARCHAR(255),
    IN p_user_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    UPDATE user_sessions
    SET 
        is_active = FALSE,
        is_deleted = TRUE,
        updated_dt = NOW(),
        updated_by = p_user_id
    WHERE token_hash = p_token_hash;
    
    -- Update user offline status
    CALL dt_vc_update_user_online_status(p_user_id, FALSE);
    
    SET p_success = TRUE;
    SET p_message = 'Session deleted successfully';
END //

DELIMITER ;


-- ----------------------------------------
-- dt_vc_cleanup_expired_sessions
-- ----------------------------------------
-- PURPOSE: Remove expired sessions (maintenance)
-- ----------------------------------------

DELIMITER //

CREATE PROCEDURE dt_vc_cleanup_expired_sessions()
BEGIN
    UPDATE user_sessions
    SET 
        is_active = FALSE,
        is_deleted = TRUE,
        updated_dt = NOW(),
        remarks = 'Auto-cleaned: Session expired'
    WHERE expires_at < NOW() 
      AND is_deleted = FALSE;
END //

DELIMITER ;


-- ============================================
-- VERIFICATION: Show all procedures
-- ============================================
SELECT 
    ROUTINE_NAME AS 'Stored Procedure',
    ROUTINE_TYPE AS 'Type'
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_SCHEMA = 'RTC_Video_Chat_DB'
ORDER BY ROUTINE_NAME;

