/**
 * ============================================
 * USER MODEL
 * ============================================
 * 
 * Handles all user-related database operations.
 * ALL operations use stored procedures - NO inline SQL!
 * 
 * METHODS:
 * - create()       : Register a new user
 * - getById()      : Get user by ID
 * - getByEmail()   : Get user by email (for login)
 * - getByUsername(): Get user by username
 * - update()       : Update user profile
 * - delete()       : Soft delete user
 * - updateOnlineStatus(): Set online/offline
 * - search()       : Search for users
 * ============================================
 */

const { callProcedure, callProcedureSingleResult, callProcedureWithResults } = require('./db');

class User {
    /**
     * Create a new user
     * 
     * @param {string} username - Unique username
     * @param {string} email - Unique email
     * @param {string} passwordHash - Already hashed password
     * @param {string} displayName - Display name
     * @param {number|null} createdBy - User ID who created this
     * @returns {Object} - { success, userId, message }
     */
    static async create(username, email, passwordHash, displayName, createdBy = null) {
        const result = await callProcedure(
            'dt_vc_create_user',
            [username, email, passwordHash, displayName, createdBy],
            ['p_user_id', 'p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            userId: result.data.p_user_id,
            message: result.data.p_message
        };
    }
    
    /**
     * Get user by ID
     * 
     * @param {number} userId - User ID
     * @returns {Object|null} - User object or null
     */
    static async getById(userId) {
        return await callProcedureSingleResult('dt_vc_get_user_by_id', [userId]);
    }
    
    /**
     * Get user by email (includes password_hash for login verification)
     * 
     * @param {string} email - Email address
     * @returns {Object|null} - User object or null
     */
    static async getByEmail(email) {
        return await callProcedureSingleResult('dt_vc_get_user_by_email', [email]);
    }
    
    /**
     * Get user by username
     * 
     * @param {string} username - Username
     * @returns {Object|null} - User object or null
     */
    static async getByUsername(username) {
        return await callProcedureSingleResult('dt_vc_get_user_by_username', [username]);
    }
    
    /**
     * Update user profile
     * 
     * @param {number} userId - User ID
     * @param {string|null} displayName - New display name
     * @param {string|null} avatarUrl - New avatar URL
     * @param {number} updatedBy - Who is making the update
     * @returns {Object} - { success, message }
     */
    static async update(userId, displayName, avatarUrl, updatedBy) {
        const result = await callProcedure(
            'dt_vc_update_user',
            [userId, displayName, avatarUrl, updatedBy],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Soft delete a user
     * 
     * @param {number} userId - User ID
     * @param {number} deletedBy - Who is deleting
     * @param {string|null} remarks - Reason for deletion
     * @returns {Object} - { success, message }
     */
    static async delete(userId, deletedBy, remarks = null) {
        const result = await callProcedure(
            'dt_vc_delete_user',
            [userId, deletedBy, remarks],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Update user's online status
     * 
     * @param {number} userId - User ID
     * @param {boolean} isOnline - Online status
     */
    static async updateOnlineStatus(userId, isOnline) {
        await callProcedure('dt_vc_update_user_online_status', [userId, isOnline], []);
    }
    
    /**
     * Search for users
     * 
     * @param {string} searchTerm - Search query
     * @param {number|null} excludeUserId - User to exclude (usually current user)
     * @returns {Array} - Array of matching users
     */
    static async search(searchTerm, excludeUserId = null) {
        const result = await callProcedureWithResults(
            'dt_vc_search_users',
            [searchTerm, excludeUserId, 10]
        );
        return result.data;
    }
}

module.exports = User;

