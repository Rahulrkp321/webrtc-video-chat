/**
 * ============================================
 * WEBRTC MANAGER
 * ============================================
 * Handles all WebRTC functionality for video calls.
 * 
 * WHAT IS WEBRTC?
 * ---------------
 * WebRTC (Web Real-Time Communication) enables peer-to-peer
 * video/audio communication directly between browsers.
 * 
 * KEY CONCEPTS:
 * 
 * 1. PEER CONNECTION (RTCPeerConnection)
 *    - The main WebRTC object
 *    - Handles the actual media connection between two peers
 *    - Each connection to another user needs one
 * 
 * 2. MEDIA STREAM (MediaStream)
 *    - Contains video and/or audio tracks
 *    - Local stream: Your camera/mic
 *    - Remote stream: Other person's camera/mic
 * 
 * 3. SDP (Session Description Protocol)
 *    - Describes what media you can send/receive
 *    - Exchanged as "offer" and "answer"
 * 
 * 4. ICE (Interactive Connectivity Establishment)
 *    - Finds the best path to connect two peers
 *    - Uses STUN/TURN servers to find public IPs
 * 
 * CONNECTION FLOW:
 * ----------------
 * 1. User A creates an "offer" (SDP)
 * 2. User A sends offer to User B via signaling server
 * 3. User B receives offer, creates "answer" (SDP)
 * 4. User B sends answer to User A
 * 5. Both exchange ICE candidates
 * 6. Connection established!
 * ============================================
 */

class WebRTCManager {
    constructor() {
        // ============================
        // CONFIGURATION
        // ============================
        
        // STUN servers help peers discover their public IP addresses
        // These are free Google STUN servers
        this.iceServers = {
            iceServers: [
                { urls: 'stun:stun.l.google.com:19302' },
                { urls: 'stun:stun1.l.google.com:19302' },
                { urls: 'stun:stun2.l.google.com:19302' },
                { urls: 'stun:stun3.l.google.com:19302' },
                { urls: 'stun:stun4.l.google.com:19302' }
            ]
        };
        
        // ============================
        // STATE
        // ============================
        
        // Local media stream (your camera/mic)
        this.localStream = null;
        
        // Map of peer connections: socketId -> RTCPeerConnection
        this.peerConnections = new Map();
        
        // Map of remote streams: socketId -> MediaStream
        this.remoteStreams = new Map();
        
        // Media state
        this.isAudioEnabled = true;
        this.isVideoEnabled = true;
        this.isScreenSharing = false;
        
        // Callbacks (set by room.js)
        this.onRemoteStream = null;      // Called when we receive a remote stream
        this.onRemoteStreamRemoved = null; // Called when a peer disconnects
        this.onIceCandidate = null;      // Called when we have an ICE candidate to send
        this.onNegotiationNeeded = null; // Called when we need to renegotiate
        
        console.log('🎥 WebRTC Manager initialized');
    }
    
    // ============================================
    // LOCAL MEDIA METHODS
    // ============================================
    
    /**
     * Get access to user's camera and microphone.
     * 
     * This prompts the browser to ask for permission.
     * Returns a MediaStream with video and audio tracks.
     * 
     * @param {Object} constraints - Media constraints
     * @returns {Promise<MediaStream>} The local media stream
     */
    async getLocalMedia(constraints = {}) {
        // Default constraints
        const defaultConstraints = {
            video: {
                width: { ideal: 1280 },
                height: { ideal: 720 },
                facingMode: 'user'  // Front camera on mobile
            },
            audio: {
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: true
            }
        };
        
        // Merge with provided constraints
        const finalConstraints = { ...defaultConstraints, ...constraints };
        
        try {
            console.log('📹 Requesting media access...');
            
            // This triggers the browser permission popup
            this.localStream = await navigator.mediaDevices.getUserMedia(finalConstraints);
            
            console.log('✅ Got local media stream');
            console.log(`   Video tracks: ${this.localStream.getVideoTracks().length}`);
            console.log(`   Audio tracks: ${this.localStream.getAudioTracks().length}`);
            
            return this.localStream;
            
        } catch (error) {
            console.error('❌ Error getting local media:', error);
            
            // Provide helpful error messages
            if (error.name === 'NotAllowedError') {
                throw new Error('Camera/microphone permission denied. Please allow access in your browser settings.');
            } else if (error.name === 'NotFoundError') {
                throw new Error('No camera or microphone found. Please connect a device.');
            } else if (error.name === 'NotReadableError') {
                throw new Error('Camera or microphone is already in use by another application.');
            } else {
                throw error;
            }
        }
    }
    
    /**
     * Toggle audio (mute/unmute microphone)
     * @returns {boolean} New audio state
     */
    toggleAudio() {
        if (!this.localStream) return false;
        
        const audioTracks = this.localStream.getAudioTracks();
        this.isAudioEnabled = !this.isAudioEnabled;
        
        audioTracks.forEach(track => {
            track.enabled = this.isAudioEnabled;
        });
        
        console.log(`🎤 Audio ${this.isAudioEnabled ? 'enabled' : 'disabled'}`);
        return this.isAudioEnabled;
    }
    
    /**
     * Toggle video (turn camera on/off)
     * @returns {boolean} New video state
     */
    toggleVideo() {
        if (!this.localStream) return false;
        
        const videoTracks = this.localStream.getVideoTracks();
        this.isVideoEnabled = !this.isVideoEnabled;
        
        videoTracks.forEach(track => {
            track.enabled = this.isVideoEnabled;
        });
        
        console.log(`📹 Video ${this.isVideoEnabled ? 'enabled' : 'disabled'}`);
        return this.isVideoEnabled;
    }
    
    /**
     * Get list of available media devices
     * @returns {Promise<Object>} Object with arrays of audio/video input/output devices
     */
    async getMediaDevices() {
        const devices = await navigator.mediaDevices.enumerateDevices();
        
        return {
            audioInputs: devices.filter(d => d.kind === 'audioinput'),
            audioOutputs: devices.filter(d => d.kind === 'audiooutput'),
            videoInputs: devices.filter(d => d.kind === 'videoinput')
        };
    }
    
    /**
     * Switch to a different camera or microphone
     * @param {string} deviceId - The device ID to switch to
     * @param {string} kind - 'audio' or 'video'
     */
    async switchDevice(deviceId, kind) {
        if (!this.localStream) return;
        
        const constraints = {
            [kind]: { deviceId: { exact: deviceId } }
        };
        
        try {
            const newStream = await navigator.mediaDevices.getUserMedia(constraints);
            const newTrack = newStream.getTracks()[0];
            
            // Replace track in local stream
            const oldTrack = kind === 'video' 
                ? this.localStream.getVideoTracks()[0]
                : this.localStream.getAudioTracks()[0];
            
            if (oldTrack) {
                this.localStream.removeTrack(oldTrack);
                oldTrack.stop();
            }
            this.localStream.addTrack(newTrack);
            
            // Replace track in all peer connections
            this.peerConnections.forEach((pc, socketId) => {
                const sender = pc.getSenders().find(s => s.track?.kind === kind);
                if (sender) {
                    sender.replaceTrack(newTrack);
                }
            });
            
            console.log(`✅ Switched ${kind} device`);
            
        } catch (error) {
            console.error(`❌ Error switching ${kind} device:`, error);
            throw error;
        }
    }
    
    // ============================================
    // PEER CONNECTION METHODS
    // ============================================
    
    /**
     * Create a new peer connection for a remote user.
     * 
     * @param {string} socketId - The socket ID of the remote user
     * @returns {RTCPeerConnection} The created peer connection
     */
    createPeerConnection(socketId) {
        console.log(`🔗 Creating peer connection for ${socketId}`);
        
        // Create new RTCPeerConnection with ICE servers
        const pc = new RTCPeerConnection(this.iceServers);
        
        // ============================
        // EVENT: ICE Candidate
        // ============================
        // Called when we discover a way to connect to this peer
        pc.onicecandidate = (event) => {
            if (event.candidate) {
                console.log(`🧊 ICE candidate for ${socketId}`);
                
                // Send candidate to the remote peer via signaling server
                if (this.onIceCandidate) {
                    this.onIceCandidate(socketId, event.candidate);
                }
            }
        };
        
        // ============================
        // EVENT: Track (Remote Media)
        // ============================
        // Called when we receive media from the remote peer
        pc.ontrack = (event) => {
            console.log(`📺 Received remote track from ${socketId}`);
            
            // Get the remote stream
            const remoteStream = event.streams[0];
            this.remoteStreams.set(socketId, remoteStream);
            
            // Notify room.js to display the video
            if (this.onRemoteStream) {
                this.onRemoteStream(socketId, remoteStream);
            }
        };
        
        // ============================
        // EVENT: ICE Connection State
        // ============================
        pc.oniceconnectionstatechange = () => {
            console.log(`🔌 ICE state for ${socketId}: ${pc.iceConnectionState}`);
            
            if (pc.iceConnectionState === 'disconnected' || 
                pc.iceConnectionState === 'failed' ||
                pc.iceConnectionState === 'closed') {
                
                // Peer disconnected
                if (this.onRemoteStreamRemoved) {
                    this.onRemoteStreamRemoved(socketId);
                }
            }
        };
        
        // ============================
        // EVENT: Negotiation Needed
        // ============================
        // Called when we need to create a new offer
        pc.onnegotiationneeded = async () => {
            console.log(`📝 Negotiation needed for ${socketId}`);
            
            if (this.onNegotiationNeeded) {
                this.onNegotiationNeeded(socketId);
            }
        };
        
        // ============================
        // Add local tracks to connection
        // ============================
        if (this.localStream) {
            this.localStream.getTracks().forEach(track => {
                pc.addTrack(track, this.localStream);
            });
            console.log(`   Added ${this.localStream.getTracks().length} local tracks`);
        }
        
        // Store the connection
        this.peerConnections.set(socketId, pc);
        
        return pc;
    }
    
    /**
     * Create an SDP offer to send to a remote peer.
     * 
     * An offer says: "Here's what media I can send/receive"
     * 
     * @param {string} socketId - The socket ID of the remote user
     * @returns {Promise<RTCSessionDescription>} The created offer
     */
    async createOffer(socketId) {
        let pc = this.peerConnections.get(socketId);
        
        if (!pc) {
            pc = this.createPeerConnection(socketId);
        }
        
        try {
            console.log(`📤 Creating offer for ${socketId}`);
            
            // Create the offer
            const offer = await pc.createOffer({
                offerToReceiveVideo: true,
                offerToReceiveAudio: true
            });
            
            // Set as our local description
            await pc.setLocalDescription(offer);
            
            console.log(`✅ Offer created for ${socketId}`);
            return pc.localDescription;
            
        } catch (error) {
            console.error(`❌ Error creating offer for ${socketId}:`, error);
            throw error;
        }
    }
    
    /**
     * Create an SDP answer in response to an offer.
     * 
     * An answer says: "I received your offer, here's what I can do"
     * 
     * @param {string} socketId - The socket ID of the remote user
     * @param {RTCSessionDescription} offer - The received offer
     * @returns {Promise<RTCSessionDescription>} The created answer
     */
    async createAnswer(socketId, offer) {
        let pc = this.peerConnections.get(socketId);
        
        if (!pc) {
            pc = this.createPeerConnection(socketId);
        }
        
        try {
            console.log(`📥 Creating answer for ${socketId}`);
            
            // Set the remote description (the offer)
            await pc.setRemoteDescription(new RTCSessionDescription(offer));
            
            // Create our answer
            const answer = await pc.createAnswer();
            
            // Set as our local description
            await pc.setLocalDescription(answer);
            
            console.log(`✅ Answer created for ${socketId}`);
            return pc.localDescription;
            
        } catch (error) {
            console.error(`❌ Error creating answer for ${socketId}:`, error);
            throw error;
        }
    }
    
    /**
     * Handle a received SDP answer.
     * 
     * @param {string} socketId - The socket ID of the remote user
     * @param {RTCSessionDescription} answer - The received answer
     */
    async handleAnswer(socketId, answer) {
        const pc = this.peerConnections.get(socketId);
        
        if (!pc) {
            console.error(`❌ No peer connection for ${socketId}`);
            return;
        }
        
        try {
            console.log(`📥 Handling answer from ${socketId}`);
            await pc.setRemoteDescription(new RTCSessionDescription(answer));
            console.log(`✅ Answer handled for ${socketId}`);
            
        } catch (error) {
            console.error(`❌ Error handling answer from ${socketId}:`, error);
        }
    }
    
    /**
     * Add a received ICE candidate.
     * 
     * @param {string} socketId - The socket ID of the remote user
     * @param {RTCIceCandidate} candidate - The received ICE candidate
     */
    async addIceCandidate(socketId, candidate) {
        const pc = this.peerConnections.get(socketId);
        
        if (!pc) {
            console.error(`❌ No peer connection for ${socketId}`);
            return;
        }
        
        try {
            await pc.addIceCandidate(new RTCIceCandidate(candidate));
            console.log(`🧊 Added ICE candidate from ${socketId}`);
            
        } catch (error) {
            console.error(`❌ Error adding ICE candidate from ${socketId}:`, error);
        }
    }
    
    /**
     * Close a peer connection.
     * 
     * @param {string} socketId - The socket ID of the remote user
     */
    closePeerConnection(socketId) {
        const pc = this.peerConnections.get(socketId);
        
        if (pc) {
            pc.close();
            this.peerConnections.delete(socketId);
            this.remoteStreams.delete(socketId);
            console.log(`🔌 Closed peer connection for ${socketId}`);
        }
    }
    
    /**
     * Close all peer connections and clean up.
     */
    closeAllConnections() {
        console.log('🔌 Closing all peer connections');
        
        // Close all peer connections
        this.peerConnections.forEach((pc, socketId) => {
            pc.close();
        });
        this.peerConnections.clear();
        this.remoteStreams.clear();
        
        // Stop local stream
        if (this.localStream) {
            this.localStream.getTracks().forEach(track => track.stop());
            this.localStream = null;
        }
    }
    
    // ============================================
    // SCREEN SHARING
    // ============================================
    
    /**
     * Start screen sharing.
     * Replaces video track with screen share.
     * 
     * @returns {Promise<MediaStream>} The screen share stream
     */
    async startScreenShare() {
        try {
            console.log('🖥️ Starting screen share...');
            
            // Get screen share stream
            const screenStream = await navigator.mediaDevices.getDisplayMedia({
                video: {
                    cursor: 'always'
                },
                audio: false
            });
            
            const screenTrack = screenStream.getVideoTracks()[0];
            
            // Handle when user stops sharing via browser UI
            screenTrack.onended = () => {
                this.stopScreenShare();
            };
            
            // Replace video track in all peer connections
            this.peerConnections.forEach((pc, socketId) => {
                const sender = pc.getSenders().find(s => s.track?.kind === 'video');
                if (sender) {
                    sender.replaceTrack(screenTrack);
                }
            });
            
            this.isScreenSharing = true;
            console.log('✅ Screen sharing started');
            
            return screenStream;
            
        } catch (error) {
            console.error('❌ Error starting screen share:', error);
            throw error;
        }
    }
    
    /**
     * Stop screen sharing.
     * Switches back to camera.
     */
    async stopScreenShare() {
        if (!this.isScreenSharing) return;
        
        try {
            console.log('🖥️ Stopping screen share...');
            
            // Get camera track
            const cameraTrack = this.localStream?.getVideoTracks()[0];
            
            if (cameraTrack) {
                // Replace screen track with camera track
                this.peerConnections.forEach((pc, socketId) => {
                    const sender = pc.getSenders().find(s => s.track?.kind === 'video');
                    if (sender) {
                        sender.replaceTrack(cameraTrack);
                    }
                });
            }
            
            this.isScreenSharing = false;
            console.log('✅ Screen sharing stopped');
            
        } catch (error) {
            console.error('❌ Error stopping screen share:', error);
        }
    }
}

// Create global instance
window.webrtcManager = new WebRTCManager();

