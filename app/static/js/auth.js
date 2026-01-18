/**
 * ============================================
 * WebRTC Video-Chat - Authentication JavaScript
 * ============================================
 * Handles user authentication on the frontend.
 * 
 * WHAT THIS FILE DOES:
 * 1. Stores JWT token in localStorage
 * 2. Makes API calls for login/register/logout
 * 3. Manages authentication state
 * 4. Redirects based on auth status
 * 
 * WHAT IS localStorage?
 * localStorage is browser storage that persists even after
 * closing the browser. We store the JWT token here.
 * 
 * Example:
 *   localStorage.setItem('token', 'abc123');
 *   localStorage.getItem('token'); // 'abc123'
 *   localStorage.removeItem('token');
 * ============================================
 */

// ============================================
// CONFIGURATION
// ============================================

const API_BASE_URL = '/api';
const AUTH_URL = `${API_BASE_URL}/auth`;

// Storage keys
const TOKEN_KEY = 'webrtc_token';
const USER_KEY = 'webrtc_user';

// ============================================
// TOKEN MANAGEMENT
// ============================================

/**
 * Save authentication data to localStorage.
 * 
 * @param {string} token - JWT token
 * @param {object} user - User data
 */
function saveAuth(token, user) {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
}

/**
 * Get the stored JWT token.
 * 
 * @returns {string|null} Token or null if not logged in
 */
function getToken() {
    return localStorage.getItem(TOKEN_KEY);
}

/**
 * Get the stored user data.
 * 
 * @returns {object|null} User object or null
 */
function getUser() {
    const userData = localStorage.getItem(USER_KEY);
    return userData ? JSON.parse(userData) : null;
}

/**
 * Clear all authentication data (logout).
 */
function clearAuth() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
}

/**
 * Check if user is logged in.
 * 
 * @returns {boolean} True if logged in
 */
function isLoggedIn() {
    return !!getToken();
}

// ============================================
// API CALLS
// ============================================

/**
 * Make an API request with proper headers.
 * 
 * @param {string} endpoint - API endpoint (e.g., '/auth/login')
 * @param {object} options - Fetch options
 * @returns {Promise<object>} API response
 * 
 * WHAT IS fetch()?
 * fetch() is the modern way to make HTTP requests in JavaScript.
 * It returns a Promise that resolves to the Response.
 */
async function apiRequest(endpoint, options = {}) {
    const url = `${API_BASE_URL}${endpoint}`;
    
    // Default headers
    const headers = {
        'Content-Type': 'application/json',
        ...options.headers
    };
    
    // Add auth token if available
    const token = getToken();
    if (token) {
        headers['Authorization'] = `Bearer ${token}`;
    }
    
    try {
        const response = await fetch(url, {
            ...options,
            headers
        });
        
        const data = await response.json();
        
        // Add HTTP status to response
        data.httpStatus = response.status;
        
        return data;
        
    } catch (error) {
        console.error('API Error:', error);
        return {
            success: false,
            message: 'Network error. Please check your connection.',
            httpStatus: 0
        };
    }
}

/**
 * Register a new user.
 * 
 * @param {string} username - Username
 * @param {string} email - Email address
 * @param {string} password - Password
 * @param {string} displayName - Display name (optional)
 * @returns {Promise<object>} API response
 */
async function register(username, email, password, displayName = '') {
    const response = await apiRequest('/auth/register', {
        method: 'POST',
        body: JSON.stringify({
            username,
            email,
            password,
            display_name: displayName || username
        })
    });
    
    // If successful, save auth data
    if (response.success && response.data) {
        saveAuth(response.data.token, response.data.user);
    }
    
    return response;
}

/**
 * Login with email/username and password.
 * 
 * @param {string} emailOrUsername - Email or username
 * @param {string} password - Password
 * @returns {Promise<object>} API response
 */
async function login(emailOrUsername, password) {
    // Determine if input is email or username
    const isEmail = emailOrUsername.includes('@');
    
    const body = {
        password
    };
    
    if (isEmail) {
        body.email = emailOrUsername;
    } else {
        body.username = emailOrUsername;
    }
    
    const response = await apiRequest('/auth/login', {
        method: 'POST',
        body: JSON.stringify(body)
    });
    
    // If successful, save auth data
    if (response.success && response.data) {
        saveAuth(response.data.token, response.data.user);
    }
    
    return response;
}

/**
 * Logout the current user.
 * 
 * @returns {Promise<object>} API response
 */
async function logout() {
    const response = await apiRequest('/auth/logout', {
        method: 'POST'
    });
    
    // Clear local storage regardless of API response
    clearAuth();
    
    return response;
}

/**
 * Get current user profile.
 * 
 * @returns {Promise<object>} API response with user data
 */
async function getCurrentUser() {
    return await apiRequest('/auth/me', {
        method: 'GET'
    });
}

/**
 * Check if current token is valid.
 * 
 * @returns {Promise<boolean>} True if token is valid
 */
async function checkAuth() {
    if (!isLoggedIn()) {
        return false;
    }
    
    const response = await apiRequest('/auth/check', {
        method: 'GET'
    });
    
    if (!response.success) {
        // Token is invalid, clear it
        clearAuth();
        return false;
    }
    
    return true;
}

// ============================================
// PAGE PROTECTION
// ============================================

/**
 * Redirect to login if not authenticated.
 * Call this on protected pages.
 */
async function requireAuth() {
    const isValid = await checkAuth();
    
    if (!isValid) {
        // Save current URL to redirect back after login
        sessionStorage.setItem('redirect_after_login', window.location.pathname);
        window.location.href = '/login';
    }
}

/**
 * Redirect to dashboard if already logged in.
 * Call this on login/register pages.
 */
async function redirectIfLoggedIn() {
    if (isLoggedIn()) {
        const isValid = await checkAuth();
        if (isValid) {
            window.location.href = '/dashboard';
        }
    }
}

/**
 * Get redirect URL after login.
 * 
 * @returns {string} URL to redirect to
 */
function getRedirectUrl() {
    const savedUrl = sessionStorage.getItem('redirect_after_login');
    sessionStorage.removeItem('redirect_after_login');
    return savedUrl || '/dashboard';
}

// ============================================
// UI HELPERS
// ============================================

/**
 * Show a toast notification.
 * 
 * @param {string} message - Message to display
 * @param {string} type - 'success', 'error', or 'info'
 */
function showToast(message, type = 'info') {
    // Create toast container if it doesn't exist
    let container = document.querySelector('.toast-container');
    if (!container) {
        container = document.createElement('div');
        container.className = 'toast-container';
        document.body.appendChild(container);
    }
    
    // Create toast element
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    // Icon based on type
    const icons = {
        success: '✅',
        error: '❌',
        info: 'ℹ️'
    };
    
    toast.innerHTML = `
        <span class="toast-icon">${icons[type] || icons.info}</span>
        <span class="toast-message">${message}</span>
    `;
    
    container.appendChild(toast);
    
    // Remove after 4 seconds
    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s ease-out reverse';
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}

/**
 * Show loading state on a button.
 * 
 * @param {HTMLElement} button - Button element
 * @param {boolean} loading - Whether to show loading
 */
function setButtonLoading(button, loading) {
    if (loading) {
        button.disabled = true;
        button.classList.add('btn-loading');
        button.dataset.originalText = button.textContent;
    } else {
        button.disabled = false;
        button.classList.remove('btn-loading');
        if (button.dataset.originalText) {
            button.textContent = button.dataset.originalText;
        }
    }
}

/**
 * Show form error message.
 * 
 * @param {string} inputId - Input element ID
 * @param {string} message - Error message
 */
function showFieldError(inputId, message) {
    const input = document.getElementById(inputId);
    const errorEl = document.getElementById(`${inputId}-error`);
    
    if (input) {
        input.classList.add('error');
    }
    
    if (errorEl) {
        errorEl.textContent = message;
        errorEl.classList.add('show');
    }
}

/**
 * Clear form error message.
 * 
 * @param {string} inputId - Input element ID
 */
function clearFieldError(inputId) {
    const input = document.getElementById(inputId);
    const errorEl = document.getElementById(`${inputId}-error`);
    
    if (input) {
        input.classList.remove('error');
    }
    
    if (errorEl) {
        errorEl.textContent = '';
        errorEl.classList.remove('show');
    }
}

/**
 * Clear all form errors.
 * 
 * @param {HTMLFormElement} form - Form element
 */
function clearAllErrors(form) {
    form.querySelectorAll('.form-input').forEach(input => {
        input.classList.remove('error');
    });
    
    form.querySelectorAll('.form-error').forEach(error => {
        error.textContent = '';
        error.classList.remove('show');
    });
}

// ============================================
// FORM VALIDATION
// ============================================

/**
 * Validate email format.
 * 
 * @param {string} email - Email to validate
 * @returns {boolean} True if valid
 */
function isValidEmail(email) {
    const pattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    return pattern.test(email);
}

/**
 * Validate username format.
 * 
 * @param {string} username - Username to validate
 * @returns {boolean} True if valid
 */
function isValidUsername(username) {
    const pattern = /^[a-zA-Z0-9_]{3,50}$/;
    return pattern.test(username);
}

/**
 * Validate password strength.
 * 
 * @param {string} password - Password to validate
 * @returns {boolean} True if valid
 */
function isValidPassword(password) {
    return password.length >= 6;
}

// ============================================
// NAVIGATION HELPERS
// ============================================

/**
 * Update navigation based on auth state.
 * Call this on page load.
 */
function updateNavigation() {
    const user = getUser();
    const loggedIn = isLoggedIn();
    
    // Elements to show/hide
    const authNav = document.getElementById('auth-nav');
    const userNav = document.getElementById('user-nav');
    const userNameEl = document.getElementById('user-display-name');
    const userAvatarEl = document.getElementById('user-avatar');
    
    if (loggedIn && user) {
        // Show user menu, hide auth links
        if (authNav) authNav.classList.add('hidden');
        if (userNav) userNav.classList.remove('hidden');
        
        // Update user info
        if (userNameEl) userNameEl.textContent = user.display_name || user.username;
        if (userAvatarEl) userAvatarEl.textContent = (user.display_name || user.username).charAt(0).toUpperCase();
    } else {
        // Show auth links, hide user menu
        if (authNav) authNav.classList.remove('hidden');
        if (userNav) userNav.classList.add('hidden');
    }
}

// ============================================
// INITIALIZE ON PAGE LOAD
// ============================================

document.addEventListener('DOMContentLoaded', () => {
    // Update navigation on every page
    updateNavigation();
});

// ============================================
// EXPORT FOR USE IN OTHER FILES
// ============================================

// Make functions available globally
window.Auth = {
    // Token management
    saveAuth,
    getToken,
    getUser,
    clearAuth,
    isLoggedIn,
    
    // API calls
    register,
    login,
    logout,
    getCurrentUser,
    checkAuth,
    
    // Page protection
    requireAuth,
    redirectIfLoggedIn,
    getRedirectUrl,
    
    // UI helpers
    showToast,
    setButtonLoading,
    showFieldError,
    clearFieldError,
    clearAllErrors,
    
    // Validation
    isValidEmail,
    isValidUsername,
    isValidPassword,
    
    // Navigation
    updateNavigation
};

