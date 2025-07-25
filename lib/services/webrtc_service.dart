import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'signaling_service.dart';

class WebRTCService extends ChangeNotifier {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // Audio analysis
  Timer? _audioAnalysisTimer;
  bool _isLocalAudioActive = false;
  bool _isRemoteAudioActive = false;
  double _localAudioLevel = 0.0;
  double _remoteAudioLevel = 0.0;
  
  // Connection state
  RTCPeerConnectionState _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
  bool _isConnected = false;
  bool _isMuted = false;
  
  // Signaling
  late SignalingService _signalingService;
  String? _sessionId;
  String? _partnerId;
  
  // Interruption detection
  DateTime? _lastLocalSpeechTime;
  DateTime? _lastRemoteSpeechTime;
  bool _isInterruption = false;
  final Duration _interruptionThreshold = const Duration(milliseconds: 500);
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isLocalAudioActive => _isLocalAudioActive;
  bool get isRemoteAudioActive => _isRemoteAudioActive;
  double get localAudioLevel => _localAudioLevel;
  double get remoteAudioLevel => _remoteAudioLevel;
  bool get isInterruption => _isInterruption;
  RTCPeerConnectionState get connectionState => _connectionState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // Initialize WebRTC service
  Future<void> initialize(String sessionId, String partnerId) async {
    _sessionId = sessionId;
    _partnerId = partnerId;
    
    // Initialize signaling service
    _signalingService = SignalingService();
    await _signalingService.connect(sessionId);
    
    // Set up signaling callbacks
    _signalingService.onOfferReceived = _handleOfferReceived;
    _signalingService.onAnswerReceived = _handleAnswerReceived;
    _signalingService.onIceCandidateReceived = _handleIceCandidateReceived;
    _signalingService.onPartnerDisconnected = _handlePartnerDisconnected;
    _signalingService.onPartnerConnected = _handlePartnerConnected;
    
    // Create peer connection
    await _createPeerConnection();
    
    // Start local media
    await _startLocalMedia();
    
    // Start audio analysis
    _startAudioAnalysis();
    
    notifyListeners();
  }

  // Create WebRTC peer connection
  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302',
            'stun:stun3.l.google.com:19302',
            'stun:stun4.l.google.com:19302',
          ]
        },
        // Free TURN servers for development/testing
        {
          'urls': [
            'turn:openrelay.metered.ca:80',
            'turn:openrelay.metered.ca:443',
          ],
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        // Additional free TURN server
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        }
      ]
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
      'sdpSemantics': 'unified-plan'
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    // Set up event handlers
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && _partnerId != null) {
        _signalingService.sendIceCandidate(candidate, _partnerId!);
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      _connectionState = state;
      _isConnected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      notifyListeners();
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (kDebugMode) {
        print('ICE Connection State: $state');
      }
    };
  }

  // Start local media (microphone)
  Future<void> _startLocalMedia() async {
    try {
      final constraints = {
        'audio': {
          'mandatory': {
            'googEchoCancellation': true,
            'googAutoGainControl': true,
            'googNoiseSuppression': true,
            'googHighpassFilter': true
          },
          'optional': []
        },
        'video': false, // Audio only for couples therapy
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      if (_peerConnection != null && _localStream != null) {
        // Use addTrack instead of addStream for Unified Plan compatibility
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error starting local media: $e');
      }
      rethrow;
    }
  }

  // Create and send offer
  Future<void> createOffer() async {
    if (_peerConnection == null || _partnerId == null) return;

    try {
      RTCSessionDescription description = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      
      await _peerConnection!.setLocalDescription(description);
      await _signalingService.sendOffer(description, _partnerId!);
      
      if (kDebugMode) {
        print('Offer created and sent to partner: $_partnerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating offer: $e');
      }
    }
  }

  // Handle received offer
  Future<void> _handleOfferReceived(RTCSessionDescription offer, String fromId) async {
    if (_peerConnection == null) return;

    try {
      if (kDebugMode) {
        print('Received offer from: $fromId, setting remote description');
      }
      
      await _peerConnection!.setRemoteDescription(offer);
      
      if (kDebugMode) {
        print('Creating answer for: $fromId');
      }
      
      RTCSessionDescription answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      
      await _peerConnection!.setLocalDescription(answer);
      await _signalingService.sendAnswer(answer, fromId);
      
      if (kDebugMode) {
        print('Answer sent to: $fromId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling offer: $e');
      }
    }
  }

  // Handle received answer
  Future<void> _handleAnswerReceived(RTCSessionDescription answer, String fromId) async {
    if (_peerConnection == null) return;

    try {
      if (kDebugMode) {
        print('Received answer from: $fromId, setting remote description');
      }
      
      await _peerConnection!.setRemoteDescription(answer);
      
      if (kDebugMode) {
        print('Answer processed successfully from: $fromId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling answer: $e');
      }
    }
  }

  // Handle received ICE candidate
  Future<void> _handleIceCandidateReceived(RTCIceCandidate candidate, String fromId) async {
    if (_peerConnection == null) return;

    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding ICE candidate: $e');
      }
    }
  }

  // Handle partner connection
  void _handlePartnerConnected(String partnerId) {
    _partnerId = partnerId;
    
    // Only create offer if we're the "caller" (determined by lexicographic comparison of IDs)
    // This ensures only one side creates an offer while the other waits for it
    if (_signalingService.localId != null && 
        _signalingService.localId!.compareTo(partnerId) < 0) {
      if (kDebugMode) {
        print('I am the caller, creating offer for partner: $partnerId');
      }
      Timer(const Duration(milliseconds: 1000), () async {
        await createOffer();
      });
    } else {
      if (kDebugMode) {
        print('I am the callee, waiting for offer from partner: $partnerId');
      }
    }
    notifyListeners();
  }

  // Handle partner disconnection
  void _handlePartnerDisconnected(String partnerId) {
    _isConnected = false;
    _remoteStream = null;
    notifyListeners();
  }

  // Start audio analysis for interruption detection and visualization
  void _startAudioAnalysis() {
    _audioAnalysisTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _analyzeAudioLevels();
      _detectInterruptions();
    });
  }

  // Analyze audio levels for visualization
  void _analyzeAudioLevels() {
    // Simulate audio level detection
    // In a real implementation, you would analyze actual audio data
    final random = Random();
    
    // Local audio level simulation based on microphone activity
    if (_localStream != null && !_isMuted) {
      // Simulate varying audio levels when speaking
      if (random.nextDouble() > 0.7) {
        _localAudioLevel = 0.3 + (random.nextDouble() * 0.7);
        _isLocalAudioActive = _localAudioLevel > 0.4;
        if (_isLocalAudioActive) {
          _lastLocalSpeechTime = DateTime.now();
        }
      } else {
        _localAudioLevel = random.nextDouble() * 0.3;
        _isLocalAudioActive = false;
      }
    } else {
      _localAudioLevel = 0.0;
      _isLocalAudioActive = false;
    }

    // Remote audio level simulation
    if (_remoteStream != null) {
      if (random.nextDouble() > 0.8) {
        _remoteAudioLevel = 0.3 + (random.nextDouble() * 0.7);
        _isRemoteAudioActive = _remoteAudioLevel > 0.4;
        if (_isRemoteAudioActive) {
          _lastRemoteSpeechTime = DateTime.now();
        }
      } else {
        _remoteAudioLevel = random.nextDouble() * 0.3;
        _isRemoteAudioActive = false;
      }
    } else {
      _remoteAudioLevel = 0.0;
      _isRemoteAudioActive = false;
    }

    notifyListeners();
  }

  // Detect interruptions based on speaking patterns
  void _detectInterruptions() {
    final now = DateTime.now();
    bool previousInterruption = _isInterruption;
    
    // Check if both partners are speaking simultaneously
    if (_isLocalAudioActive && _isRemoteAudioActive) {
      // Check if this is a new interruption (within threshold)
      if (_lastLocalSpeechTime != null && _lastRemoteSpeechTime != null) {
        final localRemoteTimeDiff = _lastLocalSpeechTime!.difference(_lastRemoteSpeechTime!).abs();
        if (localRemoteTimeDiff < _interruptionThreshold) {
          _isInterruption = true;
        }
      }
    } else {
      _isInterruption = false;
    }

    // Notify listeners only if interruption state changed
    if (previousInterruption != _isInterruption) {
      notifyListeners();
    }
  }

  // Mute/unmute microphone
  Future<void> toggleMute() async {
    if (_localStream != null) {
      _isMuted = !_isMuted;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
      notifyListeners();
    }
  }

  // Set mute state
  Future<void> setMuted(bool muted) async {
    if (_localStream != null && _isMuted != muted) {
      _isMuted = muted;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
      notifyListeners();
    }
  }

  // Get current audio statistics
  Map<String, dynamic> getAudioStats() {
    return {
      'localLevel': _localAudioLevel,
      'remoteLevel': _remoteAudioLevel,
      'localActive': _isLocalAudioActive,
      'remoteActive': _isRemoteAudioActive,
      'isInterruption': _isInterruption,
      'connectionState': _connectionState.toString(),
      'isConnected': _isConnected,
    };
  }

  // Clean shutdown
  Future<void> dispose() async {
    _audioAnalysisTimer?.cancel();
    
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    await _signalingService.disconnect();
    
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    
    _isConnected = false;
    _isLocalAudioActive = false;
    _isRemoteAudioActive = false;
    _localAudioLevel = 0.0;
    _remoteAudioLevel = 0.0;
    _isInterruption = false;
    
    notifyListeners();
  }

  // Force connection cleanup (for session end)
  Future<void> endSession() async {
    if (_signalingService != null) {
      await _signalingService.sendSessionEnd(_partnerId!);
    }
    await dispose();
  }
}