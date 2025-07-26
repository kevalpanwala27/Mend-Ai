import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  // Firebase references
  late CollectionReference _signalingCollection;
  late DocumentReference _sessionDoc;
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  
  // Connection info
  String? _sessionId;
  String? _localId;
  bool _isConnected = false;
  
  // Getters
  String? get localId => _localId;
  
  // Callbacks for WebRTC events
  Function(RTCSessionDescription offer, String fromId)? onOfferReceived;
  Function(RTCSessionDescription answer, String fromId)? onAnswerReceived;
  Function(RTCIceCandidate candidate, String fromId)? onIceCandidateReceived;
  Function(String partnerId)? onPartnerDisconnected;
  Function(String partnerId)? onPartnerConnected;
  Function(Map<String, dynamic> data, String fromId)? onCustomMessage;

  // Message types
  static const String _messageTypeOffer = 'offer';
  static const String _messageTypeAnswer = 'answer';
  static const String _messageTypeIceCandidate = 'ice_candidate';
  static const String _messageTypeSessionEnd = 'session_end';
  static const String _messageTypeHeartbeat = 'heartbeat';
  static const String _messageTypeCustom = 'custom';

  // Heartbeat timer
  Timer? _heartbeatTimer;
  final Duration _heartbeatInterval = const Duration(seconds: 30);

  // Connect to signaling server (Firebase)
  Future<void> connect(String sessionId) async {
    _sessionId = sessionId;
    _localId = const Uuid().v4();
    
    // Initialize Firebase references
    _signalingCollection = FirebaseFirestore.instance.collection('signaling');
    _sessionDoc = _signalingCollection.doc(sessionId);
    
    try {
      // Create or join session
      await _initializeSession();
      
      // Start listening for messages
      _startListening();
      
      // Start heartbeat
      _startHeartbeat();
      
      _isConnected = true;
      
      if (kDebugMode) {
        print('Signaling service connected to session: $sessionId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to signaling service: $e');
      }
      rethrow;
    }
  }

  // Initialize session document
  Future<void> _initializeSession() async {
    final sessionSnapshot = await _sessionDoc.get();
    
    if (!sessionSnapshot.exists) {
      // Create new session
      await _sessionDoc.set({
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [_localId],
        'status': 'waiting',
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } else {
      // Join existing session
      await _sessionDoc.update({
        'participants': FieldValue.arrayUnion([_localId]),
        'status': 'active',
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }
  }

  // Start listening for signaling messages
  void _startListening() {
    // Listen for session changes
    _sessionSubscription = _sessionDoc.snapshots().listen(
      _handleSessionUpdate,
      onError: (error) {
        if (kDebugMode) {
          print('Session subscription error: $error');
        }
      },
    );

    // Listen for signaling messages
    _messagesSubscription = _sessionDoc
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(
      _handleMessages,
      onError: (error) {
        if (kDebugMode) {
          print('Messages subscription error: $error');
        }
      },
    );
  }

  // Handle session document updates
  void _handleSessionUpdate(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;
    
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;
    
    // Safely handle participants list
    final participantsData = data['participants'];
    final participants = <String>[];
    
    if (participantsData is List) {
      participants.addAll(participantsData.cast<String>());
    } else if (participantsData is Map) {
      // Handle case where participants might be stored as a map
      participants.addAll(participantsData.keys.cast<String>());
    }
    
    final status = data['status'] as String?;
    
    // Check for partner connection/disconnection
    final otherParticipants = participants.where((id) => id != _localId).toList();
    
    if (otherParticipants.isNotEmpty && onPartnerConnected != null) {
      onPartnerConnected!(otherParticipants.first);
    }
    
    // Handle session status changes
    if (status == 'ended') {
      _handleSessionEnded();
    }
  }

  // Handle incoming signaling messages
  void _handleMessages(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        
        final fromId = data['fromId'] as String?;
        final type = data['type'] as String?;
        final payload = data['payload'] as Map<String, dynamic>?;
        
        // Skip messages from self
        if (fromId == _localId) continue;
        
        // Process message based on type
        _processMessage(type, payload, fromId);
        
        // Clean up old messages (optional)
        _cleanupOldMessage(change.doc.id);
      }
    }
  }

  // Process different types of signaling messages
  void _processMessage(String? type, Map<String, dynamic>? payload, String? fromId) {
    if (type == null || payload == null || fromId == null) return;
    
    switch (type) {
      case _messageTypeOffer:
        if (onOfferReceived != null) {
          final offer = RTCSessionDescription(
            payload['sdp'] as String,
            payload['type'] as String,
          );
          onOfferReceived!(offer, fromId);
        }
        break;
        
      case _messageTypeAnswer:
        if (onAnswerReceived != null) {
          final answer = RTCSessionDescription(
            payload['sdp'] as String,
            payload['type'] as String,
          );
          onAnswerReceived!(answer, fromId);
        }
        break;
        
      case _messageTypeIceCandidate:
        if (onIceCandidateReceived != null) {
          final candidate = RTCIceCandidate(
            payload['candidate'] as String,
            payload['sdpMid'] as String?,
            payload['sdpMLineIndex'] as int?,
          );
          onIceCandidateReceived!(candidate, fromId);
        }
        break;
        
      case _messageTypeSessionEnd:
        if (onPartnerDisconnected != null) {
          onPartnerDisconnected!(fromId);
        }
        break;
        
      case _messageTypeCustom:
        if (onCustomMessage != null) {
          onCustomMessage!(payload, fromId);
        }
        break;
        
      case _messageTypeHeartbeat:
        // Handle heartbeat (update last seen, etc.)
        break;
    }
  }

  // Send WebRTC offer
  Future<void> sendOffer(RTCSessionDescription offer, String toId) async {
    if (kDebugMode) {
      print('Sending offer to: $toId');
    }
    await _sendMessage(_messageTypeOffer, {
      'sdp': offer.sdp,
      'type': offer.type,
    }, toId);
  }

  // Send WebRTC answer
  Future<void> sendAnswer(RTCSessionDescription answer, String toId) async {
    if (kDebugMode) {
      print('Sending answer to: $toId');
    }
    await _sendMessage(_messageTypeAnswer, {
      'sdp': answer.sdp,
      'type': answer.type,
    }, toId);
  }

  // Send ICE candidate
  Future<void> sendIceCandidate(RTCIceCandidate candidate, String toId) async {
    if (kDebugMode) {
      print('Sending ICE candidate to: $toId');
    }
    await _sendMessage(_messageTypeIceCandidate, {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    }, toId);
  }

  // Send session end signal
  Future<void> sendSessionEnd(String toId) async {
    await _sendMessage(_messageTypeSessionEnd, {
      'reason': 'user_left',
    }, toId);
  }

  // Send custom message (for AI prompts, etc.)
  Future<void> sendCustomMessage(Map<String, dynamic> data, String toId) async {
    await _sendMessage(_messageTypeCustom, data, toId);
  }

  // Send heartbeat to keep connection alive
  Future<void> _sendHeartbeat() async {
    if (!_isConnected || _sessionId == null) return;
    
    try {
      await _sessionDoc.update({
        'lastActivity': FieldValue.serverTimestamp(),
        'participants.$_localId.lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error sending heartbeat: $e');
      }
    }
  }

  // Generic message sending method
  Future<void> _sendMessage(String type, Map<String, dynamic> payload, String toId) async {
    if (!_isConnected || _sessionId == null) {
      throw Exception('Signaling service not connected');
    }
    
    try {
      await _sessionDoc.collection('messages').add({
        'type': type,
        'fromId': _localId,
        'toId': toId,
        'payload': payload,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        print('Sent signaling message: $type');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      rethrow;
    }
  }

  // Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      _sendHeartbeat();
    });
  }

  // Clean up old messages to prevent database bloat
  Future<void> _cleanupOldMessage(String messageId) async {
    // Delete message after a delay to ensure all clients have processed it
    Timer(const Duration(minutes: 5), () async {
      try {
        await _sessionDoc.collection('messages').doc(messageId).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    });
  }

  // Handle session ended
  void _handleSessionEnded() {
    _isConnected = false;
    if (onPartnerDisconnected != null) {
      onPartnerDisconnected!('session_ended');
    }
  }

  // Get session participants
  Future<List<String>> getParticipants() async {
    try {
      final snapshot = await _sessionDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        return List<String>.from(data?['participants'] ?? []);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting participants: $e');
      }
    }
    return [];
  }

  // Check if session is active
  Future<bool> isSessionActive() async {
    try {
      final snapshot = await _sessionDoc.get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        return data?['status'] == 'active';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking session status: $e');
      }
    }
    return false;
  }

  // End session for all participants
  Future<void> endSession() async {
    if (!_isConnected || _sessionId == null) return;
    
    try {
      await _sessionDoc.update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': _localId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error ending session: $e');
      }
    }
  }

  // Disconnect from signaling service
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    
    // Remove self from participants
    if (_isConnected && _sessionId != null && _localId != null) {
      try {
        await _sessionDoc.update({
          'participants': FieldValue.arrayRemove([_localId]),
          'lastActivity': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if (kDebugMode) {
          print('Error removing participant: $e');
        }
      }
    }
    
    // Cancel subscriptions
    await _sessionSubscription?.cancel();
    await _messagesSubscription?.cancel();
    
    _sessionSubscription = null;
    _messagesSubscription = null;
    _isConnected = false;
    _sessionId = null;
    _localId = null;
    
    if (kDebugMode) {
      print('Signaling service disconnected');
    }
  }

  // Additional getters
  bool get isConnected => _isConnected;
  String? get sessionId => _sessionId;
}