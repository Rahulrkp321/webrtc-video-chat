/**
 * ============================================
 * ROOM PAGE CONTROLLER
 * ============================================
 * Handles the video chat room UI and Socket.IO communication.
 * 
 * This file connects:
 * - WebRTC Manager (webrtc.js) - for peer-to-peer video
 * - Socket.IO - for signaling (exchanging connection info)
 * - UI elements - buttons, video containers, chat
 * 
 * FLOW:
 * 1. Page loads → Connect to Socket.IO
 * 2. Authenticate with JWT token
 * 3. Join the room
 * 4. When another user joins → Create WebRTC connection
 * 5. Exchange offers/answers/ICE candidates
 * 6. Video streams flow directly between browsers
 * ============================================
 */

class RoomController {
    constructor() {
        // ============================
        // STATE
        // ============================
        this.socket = null;
        this.roomCode = window.ROOM_CODE;
        this.currentUser = null;
        this.participants = new Map(); // socketId -> {user_id, username}
        
        // ============================
        // DOM ELEMENTS
        // ============================
        this.elements = {
            // Room info
            roomName: document.getElementById('roomName'),
            roomCode: document.getElementById('roomCode'),
            participantCount: document.getElementById('participantCount'),
            copyRoomCode: document.getElementById('copyRoomCode'),
            
            // Video
            videoGrid: document.getElementById('videoGrid'),
            localVideo: document.getElementById('localVideo'),
            localVideoContainer: document.getElementById('localVideoContainer'),
            localMicIndicator: document.getElementById('localMicIndicator'),
            localCamIndicator: document.getElementById('localCamIndicator'),
            
            // Controls
            toggleMicBtn: document.getElementById('toggleMicBtn'),
            toggleCamBtn: document.getElementById('toggleCamBtn'),
            toggleScreenBtn: document.getElementById('toggleScreenBtn'),
            leaveRoomBtn: document.getElementById('leaveRoomBtn'),
            toggleChatBtn: document.getElementById('toggleChatBtn'),
            settingsBtn: document.getElementById('settingsBtn'),
            
            // Chat
            chatPanel: document.getElementById('chatPanel'),
            chatMessages: document.getElementById('chatMessages'),
            chatForm: document.getElementById('chatForm'),
            chatInput: document.getElementById('chatInput'),
            closeChatBtn: document.getElementById('closeChatBtn'),
            
            // Settings modal
            settingsModal: document.getElementById('settingsModal'),
            closeSettingsBtn: document.getElementById('closeSettingsBtn'),
            audioInput: document.getElementById('audioInput'),
            videoInput: document.getElementById('videoInput'),
            audioOutput: document.getElementById('audioOutput'),
            
            // Status
            connectionStatus: document.getElementById('connectionStatus'),
            toastContainer: document.getElementById('toastContainer')
        };
        
        // Initialize
        this.init();
    }
    
    // ============================================
    // INITIALIZATION
    // ============================================
    
    async init() {
        console.log('🚀 Initializing room...');
        console.log(`   Room code: ${this.roomCode}`);
        
        // Check if user is logged in
        const token = localStorage.getItem('token');
        if (!token) {
            window.location.href = '/login?redirect=' + encodeURIComponent(window.location.pathname);
            return;
        }
        
        try {
            // 1. Get user info from token
            this.currentUser = JSON.parse(localStorage.getItem('user'));
            
            // 2. Set up event listeners
            this.setupEventListeners();
            
            // 3. Get local media (camera/mic)
            await this.setupLocalMedia();
            
            // 4. Connect to Socket.IO
            await this.connectSocket();
            
            // 5. Set up WebRTC callbacks
            this.setupWebRTCCallbacks();
            
        } catch (error) {
            console.error('❌ Error initializing room:', error);
            this.showToast(error.message, 'error');
            this.updateConnectionStatus('error', error.message);
        }
    }
    
    // ============================================
    // EVENT LISTENERS
    // ============================================
    
    setupEventListeners() {
        // Copy room code
        this.elements.copyRoomCode.addEventListener('click', () => {
            navigator.clipboard.writeText(this.roomCode);
            this.showToast('Room code copied!', 'success');
        });
        
        // Toggle microphone
        this.elements.toggleMicBtn.addEventListener('click', () => {
            const isOn = window.webrtcManager.toggleAudio();
            this.updateMicButton(isOn);
            this.socket.emit('toggle_audio', { is_audio_on: isOn });
        });
        
        // Toggle camera
        this.elements.toggleCamBtn.addEventListener('click', () => {
            const isOn = window.webrtcManager.toggleVideo();
            this.updateCamButton(isOn);
            this.socket.emit('toggle_video', { is_video_on: isOn });
        });
        
        // Toggle screen share
        this.elements.toggleScreenBtn.addEventListener('click', async () => {
            try {
                if (window.webrtcManager.isScreenSharing) {
                    await window.webrtcManager.stopScreenShare();
                    this.elements.toggleScreenBtn.classList.remove('active');
                } else {
                    await window.webrtcManager.startScreenShare();
                    this.elements.toggleScreenBtn.classList.add('active');
                }
            } catch (error) {
                this.showToast('Screen share failed', 'error');
            }
        });
        
        // Leave room
        this.elements.leaveRoomBtn.addEventListener('click', () => {
            this.leaveRoom();
        });
        
        // Toggle chat
        this.elements.toggleChatBtn.addEventListener('click', () => {
            this.elements.chatPanel.classList.toggle('hidden');
            this.elements.toggleChatBtn.classList.toggle('active');
        });
        
        // Close chat
        this.elements.closeChatBtn.addEventListener('click', () => {
            this.elements.chatPanel.classList.add('hidden');
            this.elements.toggleChatBtn.classList.remove('active');
        });
        
        // Send chat message
        this.elements.chatForm.addEventListener('submit', (e) => {
            e.preventDefault();
            this.sendChatMessage();
        });
        
        // Settings modal
        this.elements.settingsBtn.addEventListener('click', () => {
            this.openSettings();
        });
        
        this.elements.closeSettingsBtn.addEventListener('click', () => {
            this.elements.settingsModal.classList.remove('show');
        });
        
        // Device selection
        this.elements.audioInput.addEventListener('change', async (e) => {
            await window.webrtcManager.switchDevice(e.target.value, 'audio');
        });
        
        this.elements.videoInput.addEventListener('change', async (e) => {
            await window.webrtcManager.switchDevice(e.target.value, 'video');
        });
        
        // Handle page unload
        window.addEventListener('beforeunload', () => {
            this.leaveRoom();
        });
    }
    
    // ============================================
    // LOCAL MEDIA
    // ============================================
    
    async setupLocalMedia() {
        try {
            this.updateConnectionStatus('connecting', 'Accessing camera...');
            
            const stream = await window.webrtcManager.getLocalMedia();
            
            // Display local video
            this.elements.localVideo.srcObject = stream;
            
            console.log('✅ Local media set up');
            
        } catch (error) {
            console.error('❌ Error setting up local media:', error);
            throw error;
        }
    }
    
    // ============================================
    // SOCKET.IO CONNECTION
    // ============================================
    
    async connectSocket() {
        return new Promise((resolve, reject) => {
            this.updateConnectionStatus('connecting', 'Connecting to server...');
            
            // Connect to Socket.IO server
            this.socket = io({
                transports: ['websocket', 'polling']
            });
            
            // ============================
            // CONNECTION EVENTS
            // ============================
            
            this.socket.on('connect', () => {
                console.log('🔌 Connected to server');
                this.updateConnectionStatus('connecting', 'Authenticating...');
                
                // Authenticate with JWT token
                const token = localStorage.getItem('token');
                this.socket.emit('authenticate', { token });
            });
            
            this.socket.on('disconnect', () => {
                console.log('🔌 Disconnected from server');
                this.updateConnectionStatus('error', 'Disconnected');
            });
            
            this.socket.on('connect_error', (error) => {
                console.error('❌ Connection error:', error);
                this.updateConnectionStatus('error', 'Connection failed');
                reject(error);
            });
            
            // ============================
            // AUTHENTICATION
            // ============================
            
            this.socket.on('authenticated', (data) => {
                if (data.success) {
                    console.log('✅ Authenticated');
                    this.updateConnectionStatus('connecting', 'Joining room...');
                    
                    // Join the room
                    this.socket.emit('join_room', { room_code: this.roomCode });
                } else {
                    console.error('❌ Authentication failed:', data.error);
                    this.updateConnectionStatus('error', 'Authentication failed');
                    reject(new Error(data.error));
                }
            });
            
            // ============================
            // ROOM EVENTS
            // ============================
            
            this.socket.on('room_joined', (data) => {
                if (data.success) {
                    console.log('✅ Joined room');
                    console.log('   Existing users:', data.users);
                    
                    // Update UI
                    this.elements.roomName.textContent = data.room.room_name || this.roomCode;
                    this.elements.roomCode.textContent = this.roomCode;
                    this.updateParticipantCount(data.user_count);
                    
                    this.updateConnectionStatus('connected', 'Connected');
                    
                    // Store existing users
                    data.users.forEach(user => {
                        this.participants.set(user.socket_id, user);
                    });
                    
                    // Create offers to existing users
                    data.users.forEach(user => {
                        this.initiateCall(user.socket_id);
                    });
                    
                    resolve();
                } else {
                    console.error('❌ Failed to join room:', data.error);
                    this.updateConnectionStatus('error', data.error);
                    reject(new Error(data.error));
                }
            });
            
            this.socket.on('user_joined', (data) => {
                console.log(`👤 User joined: ${data.username}`);
                this.showToast(`${data.username} joined the room`, 'success');
                
                // Store user
                this.participants.set(data.socket_id, data);
                this.updateParticipantCount(data.user_count);
                
                // The new user will send us an offer, we wait for it
            });
            
            this.socket.on('user_left', (data) => {
                console.log(`👋 User left: ${data.username}`);
                this.showToast(`${data.username} left the room`, 'warning');
                
                // Remove user
                this.participants.delete(data.socket_id);
                this.updateParticipantCount(data.user_count);
                
                // Close peer connection and remove video
                window.webrtcManager.closePeerConnection(data.socket_id);
                this.removeRemoteVideo(data.socket_id);
            });
            
            // ============================
            // WEBRTC SIGNALING
            // ============================
            
            this.socket.on('offer', async (data) => {
                console.log(`📥 Received offer from ${data.from_username}`);
                
                // Store user info
                this.participants.set(data.from_socket_id, {
                    socket_id: data.from_socket_id,
                    user_id: data.from_user_id,
                    username: data.from_username
                });
                
                // Create answer
                const answer = await window.webrtcManager.createAnswer(data.from_socket_id, data.sdp);
                
                // Send answer back
                this.socket.emit('answer', {
                    target_socket_id: data.from_socket_id,
                    sdp: answer
                });
            });
            
            this.socket.on('answer', async (data) => {
                console.log(`📥 Received answer from ${data.from_username}`);
                await window.webrtcManager.handleAnswer(data.from_socket_id, data.sdp);
            });
            
            this.socket.on('ice_candidate', async (data) => {
                console.log(`🧊 Received ICE candidate from ${data.from_socket_id}`);
                await window.webrtcManager.addIceCandidate(data.from_socket_id, data.candidate);
            });
            
            // ============================
            // MEDIA TOGGLE EVENTS
            // ============================
            
            this.socket.on('user_audio_toggle', (data) => {
                const videoContainer = document.getElementById(`video-${data.socket_id}`);
                if (videoContainer) {
                    const micIndicator = videoContainer.querySelector('.mic-indicator');
                    if (micIndicator) {
                        micIndicator.classList.toggle('muted', !data.is_audio_on);
                    }
                }
            });
            
            this.socket.on('user_video_toggle', (data) => {
                const videoContainer = document.getElementById(`video-${data.socket_id}`);
                if (videoContainer) {
                    const camIndicator = videoContainer.querySelector('.cam-indicator');
                    if (camIndicator) {
                        camIndicator.classList.toggle('muted', !data.is_video_on);
                    }
                }
            });
            
            // ============================
            // CHAT EVENTS
            // ============================
            
            this.socket.on('chat_message', (data) => {
                this.displayChatMessage(data);
            });
        });
    }
    
    // ============================================
    // WEBRTC CALLBACKS
    // ============================================
    
    setupWebRTCCallbacks() {
        // Called when we receive a remote stream
        window.webrtcManager.onRemoteStream = (socketId, stream) => {
            console.log(`📺 Displaying remote stream from ${socketId}`);
            this.addRemoteVideo(socketId, stream);
        };
        
        // Called when a remote stream is removed
        window.webrtcManager.onRemoteStreamRemoved = (socketId) => {
            console.log(`📺 Removing remote stream from ${socketId}`);
            this.removeRemoteVideo(socketId);
        };
        
        // Called when we have an ICE candidate to send
        window.webrtcManager.onIceCandidate = (socketId, candidate) => {
            this.socket.emit('ice_candidate', {
                target_socket_id: socketId,
                candidate: candidate
            });
        };
    }
    
    // ============================================
    // CALL MANAGEMENT
    // ============================================
    
    async initiateCall(socketId) {
        console.log(`📞 Initiating call to ${socketId}`);
        
        try {
            // Create offer
            const offer = await window.webrtcManager.createOffer(socketId);
            
            // Send offer to peer
            this.socket.emit('offer', {
                target_socket_id: socketId,
                sdp: offer
            });
            
        } catch (error) {
            console.error(`❌ Error initiating call to ${socketId}:`, error);
        }
    }
    
    // ============================================
    // VIDEO MANAGEMENT
    // ============================================
    
    addRemoteVideo(socketId, stream) {
        // Check if video container already exists
        let container = document.getElementById(`video-${socketId}`);
        
        if (!container) {
            // Get user info
            const user = this.participants.get(socketId) || { username: 'Unknown' };
            
            // Create video container
            container = document.createElement('div');
            container.id = `video-${socketId}`;
            container.className = 'video-container remote';
            container.innerHTML = `
                <video autoplay playsinline></video>
                <div class="video-label">
                    <span class="username">${user.username}</span>
                    <span class="indicators">
                        <span class="mic-indicator">🎤</span>
                        <span class="cam-indicator">📹</span>
                    </span>
                </div>
            `;
            
            this.elements.videoGrid.appendChild(container);
        }
        
        // Set video stream
        const video = container.querySelector('video');
        video.srcObject = stream;
    }
    
    removeRemoteVideo(socketId) {
        const container = document.getElementById(`video-${socketId}`);
        if (container) {
            container.remove();
        }
    }
    
    // ============================================
    // UI UPDATES
    // ============================================
    
    updateMicButton(isOn) {
        this.elements.toggleMicBtn.classList.toggle('muted', !isOn);
        this.elements.localMicIndicator.classList.toggle('muted', !isOn);
    }
    
    updateCamButton(isOn) {
        this.elements.toggleCamBtn.classList.toggle('muted', !isOn);
        this.elements.localCamIndicator.classList.toggle('muted', !isOn);
    }
    
    updateParticipantCount(count) {
        this.elements.participantCount.textContent = count;
    }
    
    updateConnectionStatus(status, message) {
        const statusEl = this.elements.connectionStatus;
        const iconEl = statusEl.querySelector('.status-icon');
        const textEl = statusEl.querySelector('.status-text');
        
        statusEl.className = 'connection-status';
        
        switch (status) {
            case 'connecting':
                iconEl.textContent = '🔄';
                statusEl.classList.remove('hidden');
                break;
            case 'connected':
                iconEl.textContent = '✅';
                statusEl.classList.add('connected');
                // Hide after 2 seconds
                setTimeout(() => {
                    statusEl.classList.add('hidden');
                }, 2000);
                break;
            case 'error':
                iconEl.textContent = '❌';
                statusEl.classList.add('error');
                break;
        }
        
        textEl.textContent = message;
    }
    
    // ============================================
    // CHAT
    // ============================================
    
    sendChatMessage() {
        const message = this.elements.chatInput.value.trim();
        
        if (message) {
            this.socket.emit('chat_message', {
                message: message,
                timestamp: new Date().toISOString()
            });
            
            this.elements.chatInput.value = '';
        }
    }
    
    displayChatMessage(data) {
        const isOwn = data.user_id === this.currentUser?.user_id;
        
        const messageEl = document.createElement('div');
        messageEl.className = `chat-message ${isOwn ? 'own' : 'other'}`;
        messageEl.innerHTML = `
            ${!isOwn ? `<div class="sender">${data.username}</div>` : ''}
            <div class="text">${this.escapeHtml(data.message)}</div>
            <div class="time">${new Date(data.timestamp).toLocaleTimeString()}</div>
        `;
        
        this.elements.chatMessages.appendChild(messageEl);
        this.elements.chatMessages.scrollTop = this.elements.chatMessages.scrollHeight;
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    // ============================================
    // SETTINGS
    // ============================================
    
    async openSettings() {
        // Get available devices
        const devices = await window.webrtcManager.getMediaDevices();
        
        // Populate audio inputs
        this.elements.audioInput.innerHTML = devices.audioInputs.map(d => 
            `<option value="${d.deviceId}">${d.label || 'Microphone ' + d.deviceId.slice(0, 8)}</option>`
        ).join('');
        
        // Populate video inputs
        this.elements.videoInput.innerHTML = devices.videoInputs.map(d => 
            `<option value="${d.deviceId}">${d.label || 'Camera ' + d.deviceId.slice(0, 8)}</option>`
        ).join('');
        
        // Populate audio outputs
        this.elements.audioOutput.innerHTML = devices.audioOutputs.map(d => 
            `<option value="${d.deviceId}">${d.label || 'Speaker ' + d.deviceId.slice(0, 8)}</option>`
        ).join('');
        
        // Show modal
        this.elements.settingsModal.classList.add('show');
    }
    
    // ============================================
    // LEAVE ROOM
    // ============================================
    
    leaveRoom() {
        console.log('👋 Leaving room...');
        
        // Notify server
        if (this.socket) {
            this.socket.emit('leave_room', { room_code: this.roomCode });
            this.socket.disconnect();
        }
        
        // Close all WebRTC connections
        window.webrtcManager.closeAllConnections();
        
        // Redirect to dashboard
        window.location.href = '/dashboard';
    }
    
    // ============================================
    // TOAST NOTIFICATIONS
    // ============================================
    
    showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        
        this.elements.toastContainer.appendChild(toast);
        
        // Remove after 3 seconds
        setTimeout(() => {
            toast.remove();
        }, 3000);
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.roomController = new RoomController();
});

