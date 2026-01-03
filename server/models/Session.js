/**
 * ============================================
 * SESSION MODEL
 * ============================================
 * 
 * Handles user session/login database operations.
 * ALL operations use stored procedures - NO inline SQL!
 * 
 * METHODS:
 * - create()  : Create a login session
 * - validate(): Validate session token
 * - delete()  : Delete session (logout)
 * - cleanup() : Remove expired sessions
 * ============================================
 */

const { callProcedure, callProcedureSingleResult } = require('./db');

class Session {
    /**
     * Create a new login session
     * 
     * @param {number} userId - User ID
     * @param {string} tokenHash - Hashed JWT token
     * @param {Date} expiresAt - When session expires
     * @param {string|null} ipAddress - User's IP address
     * @param {string|null} userAgent - User's browser info
     * @returns {Object} - { success, sessionId, message }
     */
    static async create(userId, tokenHash, expiresAt, ipAddress = null, userAgent = null) {
        const result = await callProcedure(
            'dt_vc_create_session',
            [userId, tokenHash, expiresAt, ipAddress, userAgent],
            ['p_session_id', 'p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            sessionId: result.data.p_session_id,
            message: result.data.p_message
        };
    }
    
    /**
     * Validate a session token
     * 
     * @param {string} tokenHash - Hashed JWT token
     * @returns {Object|null} - Session with user info or null
     */
    static async validate(tokenHash) {
        return await callProcedureSingleResult('dt_vc_validate_session', [tokenHash]);
    }
    
    /**
     * Delete a session (logout)
     * 
     * @param {string} tokenHash - Hashed JWT token
     * @param {number} userId - User ID
     * @returns {Object} - { success, message }
     */
    static async delete(tokenHash, userId) {
        const result = await callProcedure(
            'dt_vc_delete_session',
            [tokenHash, userId],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Cleanup expired sessions
     * This should be called periodically (e.g., by a cron job)
     */
    static async cleanup() {
        await callProcedure('dt_vc_cleanup_expired_sessions', [], []);
    }
}

module.exports = Session;

