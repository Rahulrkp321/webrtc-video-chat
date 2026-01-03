/**
 * ============================================
 * CALL LOG MODEL
 * ============================================
 * 
 * Handles all call history database operations.
 * ALL operations use stored procedures - NO inline SQL!
 * 
 * METHODS:
 * - create()        : Log a new call
 * - update()        : Update call when it ends
 * - getUserHistory(): Get call history for a user
 * ============================================
 */

const { callProcedure, callProcedureWithResults } = require('./db');

class CallLog {
    /**
     * Create a new call log
     * 
     * @param {number} roomId - Room where call is happening
     * @param {number} callerUserId - Who initiated the call
     * @param {number|null} calleeUserId - Who received the call
     * @param {number} createdBy - Who created this log
     * @returns {Object} - { success, callId, message }
     */
    static async create(roomId, callerUserId, calleeUserId = null, createdBy = null) {
        const result = await callProcedure(
            'dt_vc_create_call_log',
            [roomId, callerUserId, calleeUserId, createdBy || callerUserId],
            ['p_call_id', 'p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            callId: result.data.p_call_id,
            message: result.data.p_message
        };
    }
    
    /**
     * Update call log when call ends
     * 
     * @param {number} callId - Call ID
     * @param {string} callStatus - Status: completed, missed, declined, failed
     * @param {number} updatedBy - Who is updating
     * @returns {Object} - { success, message }
     */
    static async update(callId, callStatus, updatedBy) {
        const result = await callProcedure(
            'dt_vc_update_call_log',
            [callId, callStatus, updatedBy],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Get call history for a user
     * 
     * @param {number} userId - User ID
     * @param {number} limit - Maximum records to return
     * @param {number} offset - Skip this many records
     * @returns {Array} - Array of call logs
     */
    static async getUserHistory(userId, limit = 20, offset = 0) {
        const result = await callProcedureWithResults(
            'dt_vc_get_user_call_history',
            [userId, limit, offset]
        );
        return result.data;
    }
}

module.exports = CallLog;

