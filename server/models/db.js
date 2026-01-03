/**
 * ============================================
 * DATABASE HELPER FUNCTIONS
 * ============================================
 * 
 * These functions help call stored procedures from Node.js.
 * 
 * IMPORTANT: ALL database access MUST go through stored procedures!
 * NO inline SQL is allowed in the application.
 * 
 * WHY STORED PROCEDURES?
 * 1. Security: Prevents SQL injection
 * 2. Performance: Pre-compiled and cached
 * 3. Maintainability: Database logic in one place
 * 4. Consistency: Same operations everywhere
 * ============================================
 */

const { pool } = require('../config/database');

/**
 * Call a stored procedure with OUT parameters
 * 
 * @param {string} procedureName - Name of stored procedure (e.g., 'dt_vc_create_user')
 * @param {Array} inParams - Array of input parameter values
 * @param {Array} outParams - Array of output parameter names
 * @returns {Object} - { success, data, error }
 * 
 * EXAMPLE:
 * const result = await callProcedure(
 *     'dt_vc_create_user',
 *     ['john', 'john@email.com', 'hashedpwd', 'John Doe', null],
 *     ['p_user_id', 'p_success', 'p_message']
 * );
 * // result.data = { p_user_id: 1, p_success: 1, p_message: 'User created successfully' }
 */
async function callProcedure(procedureName, inParams = [], outParams = []) {
    // Get a connection from the pool
    const connection = await pool.getConnection();
    
    try {
        // Build the CALL statement
        // Example: CALL dt_vc_create_user(?, ?, ?, ?, ?, @p_user_id, @p_success, @p_message)
        
        // Create placeholders for input params (?)
        const inPlaceholders = inParams.map(() => '?').join(', ');
        
        // Create placeholders for output params (@param_name)
        const outPlaceholders = outParams.map(name => `@${name}`).join(', ');
        
        // Build the complete CALL statement
        let callStatement = `CALL ${procedureName}(`;
        
        const parts = [];
        if (inParams.length > 0) parts.push(inPlaceholders);
        if (outParams.length > 0) parts.push(outPlaceholders);
        
        callStatement += parts.join(', ') + ')';
        
        // Execute the stored procedure
        await connection.execute(callStatement, inParams);
        
        // If there are OUT parameters, fetch their values
        let outResults = {};
        if (outParams.length > 0) {
            // Build SELECT statement for output variables
            // Example: SELECT @p_user_id AS p_user_id, @p_success AS p_success
            const selectOut = `SELECT ${outParams.map(name => `@${name} AS ${name}`).join(', ')}`;
            const [rows] = await connection.execute(selectOut);
            outResults = rows[0] || {};
        }
        
        return { success: true, data: outResults };
        
    } catch (error) {
        console.error(`❌ Error calling ${procedureName}:`, error.message);
        return { success: false, error: error.message, data: {} };
        
    } finally {
        // ALWAYS release the connection back to the pool
        connection.release();
    }
}

/**
 * Call a stored procedure that returns a result set (SELECT)
 * 
 * @param {string} procedureName - Name of stored procedure
 * @param {Array} params - Array of parameter values
 * @returns {Object} - { success, data, error }
 * 
 * EXAMPLE:
 * const result = await callProcedureWithResults('dt_vc_get_user_by_email', ['john@email.com']);
 * // result.data = [{ user_id: 1, username: 'john', ... }]
 */
async function callProcedureWithResults(procedureName, params = []) {
    const connection = await pool.getConnection();
    
    try {
        // Create placeholders for parameters
        const placeholders = params.map(() => '?').join(', ');
        const callStatement = `CALL ${procedureName}(${placeholders})`;
        
        // Execute and get results
        const [results] = await connection.execute(callStatement, params);
        
        // MySQL returns results in an array where [0] is the actual data
        // and [1] is metadata about the query
        return { success: true, data: results[0] || [] };
        
    } catch (error) {
        console.error(`❌ Error calling ${procedureName}:`, error.message);
        return { success: false, error: error.message, data: [] };
        
    } finally {
        connection.release();
    }
}

/**
 * Call a stored procedure that returns a single row
 * 
 * @param {string} procedureName - Name of stored procedure
 * @param {Array} params - Array of parameter values
 * @returns {Object|null} - Single row or null
 */
async function callProcedureSingleResult(procedureName, params = []) {
    const result = await callProcedureWithResults(procedureName, params);
    
    if (result.success && result.data.length > 0) {
        return result.data[0];
    }
    
    return null;
}

// Export the helper functions
module.exports = {
    callProcedure,
    callProcedureWithResults,
    callProcedureSingleResult
};

