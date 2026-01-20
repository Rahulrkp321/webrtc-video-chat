"""
============================================
SOCKET PACKAGE
============================================
Contains Socket.IO event handlers for real-time communication.

WHAT IS SOCKET.IO?
------------------
Socket.IO enables real-time, bidirectional communication between
web clients and servers. Unlike HTTP (request-response), Socket.IO
maintains a persistent connection for instant messaging.

HTTP vs Socket.IO:
    HTTP:      Client → Request → Server → Response → Client
               (Connection closes after each request)
    
    Socket.IO: Client ←→ Server
               (Connection stays open, both can send anytime)

WHY DO WE NEED IT FOR WEBRTC?
-----------------------------
WebRTC needs a "signaling server" to exchange connection info
between peers BEFORE they can connect directly:

1. User A wants to call User B
2. User A sends "offer" to signaling server
3. Server forwards "offer" to User B
4. User B sends "answer" back through server
5. Both exchange ICE candidates through server
6. Once they have enough info, they connect directly (P2P)

After step 6, video/audio flows directly between browsers,
NOT through our server!
============================================
"""

from app.socket.events import register_socket_events

