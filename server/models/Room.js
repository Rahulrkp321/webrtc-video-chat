/**
 * ============================================
 * ROOM MODEL
 * ============================================
 * 
 * Handles all room-related database operations.
 * ALL operations use stored procedures - NO inline SQL!
 * 
 * METHODS:
 * - create()           : Create a new room
 * - getById()          : Get room by ID
 * - getByCode()        : Get room by code
 * - getUserRooms()     : Get all rooms for a user
 * - update()           : Update room details
 * - delete()           : Soft delete room
 * - addParticipant()   : Add user to room
 * - removeParticipant(): Remove user from room
 * - getParticipants()  : Get room participants
 * ============================================
 */

const { callProcedure, callProcedureSingleResult, callProcedureWithResults } = require('./db');

class Room {
    /**
     * Create a new room
     * 
     * @param {string} roomCode - Unique room code
     * @param {string|null} roomName - Room name
     * @param {number} ownerUserId - Owner's user ID
     * @param {boolean} isPrivate - Is room password protected
     * @param {string|null} passwordHash - Hashed password (if private)
     * @param {number} maxParticipants - Maximum participants
     * @param {number} createdBy - Who created this room
     * @returns {Object} - { success, roomId, message }
     */
    static async create(roomCode, roomName, ownerUserId, isPrivate = false, passwordHash = null, maxParticipants = 10, createdBy = null) {
        const result = await callProcedure(
            'dt_vc_create_room',
            [roomCode, roomName, ownerUserId, isPrivate, passwordHash, maxParticipants, createdBy || ownerUserId],
            ['p_room_id', 'p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            roomId: result.data.p_room_id,
            message: result.data.p_message
        };
    }
    
    /**
     * Get room by ID
     * 
     * @param {number} roomId - Room ID
     * @returns {Object|null} - Room object or null
     */
    static async getById(roomId) {
        return await callProcedureSingleResult('dt_vc_get_room_by_id', [roomId]);
    }
    
    /**
     * Get room by code
     * 
     * @param {string} roomCode - Room code
     * @returns {Object|null} - Room object or null
     */
    static async getByCode(roomCode) {
        return await callProcedureSingleResult('dt_vc_get_room_by_code', [roomCode]);
    }
    
    /**
     * Get all rooms created by a user
     * 
     * @param {number} userId - User ID
     * @returns {Array} - Array of rooms
     */
    static async getUserRooms(userId) {
        const result = await callProcedureWithResults('dt_vc_get_user_rooms', [userId]);
        return result.data;
    }
    
    /**
     * Update room details
     * 
     * @param {number} roomId - Room ID
     * @param {string|null} roomName - New room name
     * @param {boolean|null} isPrivate - Is private
     * @param {string|null} passwordHash - New password hash
     * @param {number|null} maxParticipants - New max participants
     * @param {number} updatedBy - Who is updating
     * @returns {Object} - { success, message }
     */
    static async update(roomId, roomName, isPrivate, passwordHash, maxParticipants, updatedBy) {
        const result = await callProcedure(
            'dt_vc_update_room',
            [roomId, roomName, isPrivate, passwordHash, maxParticipants, updatedBy],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Soft delete a room
     * 
     * @param {number} roomId - Room ID
     * @param {number} deletedBy - Who is deleting
     * @param {string|null} remarks - Reason for deletion
     * @returns {Object} - { success, message }
     */
    static async delete(roomId, deletedBy, remarks = null) {
        const result = await callProcedure(
            'dt_vc_delete_room',
            [roomId, deletedBy, remarks],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Add a participant to a room
     * 
     * @param {number} roomId - Room ID
     * @param {number} userId - User ID
     * @param {boolean} isHost - Is this user the host
     * @param {number} createdBy - Who added this participant
     * @returns {Object} - { success, participantId, message }
     */
    static async addParticipant(roomId, userId, isHost = false, createdBy = null) {
        const result = await callProcedure(
            'dt_vc_add_room_participant',
            [roomId, userId, isHost, createdBy || userId],
            ['p_participant_id', 'p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            participantId: result.data.p_participant_id,
            message: result.data.p_message
        };
    }
    
    /**
     * Remove a participant from a room
     * 
     * @param {number} roomId - Room ID
     * @param {number} userId - User ID
     * @returns {Object} - { success, message }
     */
    static async removeParticipant(roomId, userId) {
        const result = await callProcedure(
            'dt_vc_remove_room_participant',
            [roomId, userId],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Get all participants in a room
     * 
     * @param {number} roomId - Room ID
     * @returns {Array} - Array of participants
     */
    static async getParticipants(roomId) {
        const result = await callProcedureWithResults('dt_vc_get_room_participants', [roomId]);
        return result.data;
    }
}

module.exports = Room;

