/**
 * ============================================
 * MODELS INDEX
 * ============================================
 * 
 * Central export point for all database models.
 * 
 * USAGE:
 * const { User, Room, Contact, CallLog, Session } = require('./models');
 * 
 * ALL MODELS USE STORED PROCEDURES - NO INLINE SQL!
 * ============================================
 */

const User = require('./User');
const Room = require('./Room');
const Contact = require('./Contact');
const CallLog = require('./CallLog');
const Session = require('./Session');
const { callProcedure, callProcedureWithResults, callProcedureSingleResult } = require('./db');

module.exports = {
    User,
    Room,
    Contact,
    CallLog,
    Session,
    // Also export low-level helpers for edge cases
    callProcedure,
    callProcedureWithResults,
    callProcedureSingleResult
};

