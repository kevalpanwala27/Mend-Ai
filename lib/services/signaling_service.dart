import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SignalingService {
  // Update this to your EC2 instance IP
  static const String serverUrl = 'http://13.223.2.148:3000';

  IO.Socket? _socket;
  String? _sessionId;
  String? localId;
  String? _participantName;

  // Callbacks
  Function(RTCSessionDescription, String)? onOfferReceived;
  Function(RTCSessionDescription, String)? onAnswerReceived;
  Function(RTCIceCandidate, String)? onIceCandidateReceived;
  Function(String, String)? onPartnerConnected; // partnerId, partnerName
  Function(String)? onPartnerDisconnected;

  Future<void> connect(String sessionId, {String? participantName}) async {
    _sessionId = sessionId;
    _participantName = participantName;
    localId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      _socket = IO.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _socket!.connect();

      _setupSocketListeners();

      // Join session after connection
      _socket!.onConnect((_) {
        developer.log('Connected to signaling server');
        _joinSession();
      });
    } catch (e) {
      developer.log('Failed to connect to signaling server: $e');
      rethrow;
    }
  }

  void _setupSocketListeners() {
    _socket!.onConnect((_) {
      developer.log('Signaling service connected to session: $_sessionId');
    });

    _socket!.onDisconnect((_) {
      developer.log('Disconnected from signaling server');
    });

    _socket!.on('session-joined', (data) {
      developer.log('Successfully joined session: ${data['sessionId']}');
    });

    _socket!.on('partner-connected', (data) {
      developer.log('Partner connected: ${data['partnerId']}, name: ${data['partnerName']}');
      onPartnerConnected?.call(data['partnerId'], data['partnerName']);
    });

    _socket!.on('partner-disconnected', (data) {
      developer.log('Partner disconnected: ${data['partnerId']}');
      onPartnerDisconnected?.call(data['partnerId']);
    });

    _socket!.on('offer', (data) {
      developer.log('Received offer from: ${data['fromId']}');
      final offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );
      onOfferReceived?.call(offer, data['fromId']);
    });

    _socket!.on('answer', (data) {
      developer.log('Received answer from: ${data['fromId']}');
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      onAnswerReceived?.call(answer, data['fromId']);
    });

    _socket!.on('ice-candidate', (data) {
      developer.log('SignalingService: Received ICE candidate from: ${data['fromId']}');
      developer.log('SignalingService: Candidate data: ${data['candidate']}');
      
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      onIceCandidateReceived?.call(candidate, data['fromId']);
      developer.log('SignalingService: ICE candidate callback completed');
    });
  }

  void _joinSession() {
    _socket!.emit('join-session', {
      'sessionId': _sessionId,
      'participantId': localId,
      'participantName': _participantName ?? 'Partner', // Use actual participant name
    });
  }

  Future<void> sendOffer(RTCSessionDescription offer, String targetId) async {
    _socket!.emit('offer', {
      'sessionId': _sessionId,
      'targetId': targetId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<void> sendAnswer(RTCSessionDescription answer, String targetId) async {
    _socket!.emit('answer', {
      'sessionId': _sessionId,
      'targetId': targetId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<void> sendIceCandidate(
    RTCIceCandidate candidate,
    String targetId,
  ) async {
    developer.log('SignalingService: Preparing to send ICE candidate to $targetId');
    developer.log('SignalingService: Candidate: ${candidate.candidate}');
    
    final message = {
      'sessionId': _sessionId,
      'targetId': targetId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    };
    
    developer.log('SignalingService: Emitting ice-candidate event');
    _socket!.emit('ice-candidate', message);
    developer.log('SignalingService: ICE candidate emit completed');
  }

  Future<void> sendSessionEnd(String targetId) async {
    _socket!.emit('end-session', {'sessionId': _sessionId});
  }

  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
