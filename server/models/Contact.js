/**
 * ============================================
 * CONTACT MODEL
 * ============================================
 * 
 * Handles all contact-related database operations.
 * ALL operations use stored procedures - NO inline SQL!
 * 
 * METHODS:
 * - add()       : Add a contact
 * - getAll()    : Get all contacts for a user
 * - update()    : Update contact nickname
 * - delete()    : Remove a contact
 * ============================================
 */

const { callProcedure, callProcedureWithResults } = require('./db');

class Contact {
    /**
     * Add a contact
     * 
     * @param {number} userId - The user adding the contact
     * @param {number} contactUserId - The user being added as contact
     * @param {string|null} nickname - Optional nickname
     * @param {number} createdBy - Who is adding this
     * @returns {Object} - { success, contactId, message }
     */
    static async add(userId, contactUserId, nickname = null, createdBy = null) {
        const result = await callProcedure(
            'dt_vc_add_contact',
            [userId, contactUserId, nickname, createdBy || userId],
            ['p_contact_id', 'p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            contactId: result.data.p_contact_id,
            message: result.data.p_message
        };
    }
    
    /**
     * Get all contacts for a user
     * 
     * @param {number} userId - User ID
     * @returns {Array} - Array of contacts
     */
    static async getAll(userId) {
        const result = await callProcedureWithResults('dt_vc_get_user_contacts', [userId]);
        return result.data;
    }
    
    /**
     * Update contact nickname
     * 
     * @param {number} contactId - Contact ID
     * @param {number} userId - User ID (owner)
     * @param {string} nickname - New nickname
     * @param {number} updatedBy - Who is updating
     * @returns {Object} - { success, message }
     */
    static async update(contactId, userId, nickname, updatedBy) {
        const result = await callProcedure(
            'dt_vc_update_contact',
            [contactId, userId, nickname, updatedBy || userId],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
    
    /**
     * Remove a contact
     * 
     * @param {number} contactId - Contact ID
     * @param {number} userId - User ID (owner)
     * @param {number} deletedBy - Who is deleting
     * @returns {Object} - { success, message }
     */
    static async delete(contactId, userId, deletedBy = null) {
        const result = await callProcedure(
            'dt_vc_delete_contact',
            [contactId, userId, deletedBy || userId],
            ['p_success', 'p_message']
        );
        
        return {
            success: result.data.p_success === 1,
            message: result.data.p_message
        };
    }
}

module.exports = Contact;

