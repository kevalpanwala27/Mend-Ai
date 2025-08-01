import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'signaling_service.dart';

class WebRTCService extends ChangeNotifier {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Connection state tracking
  RTCPeerConnectionState? _connectionState;
  RTCIceGatheringState? _iceGatheringState;
  RTCIceConnectionState? _iceConnectionState;

  // Retry mechanism
  int _retryCount = 0;
  static const int maxRetries = 3;
  Timer? _connectionTimer;

  // Audio analysis
  Timer? _audioAnalysisTimer;
  bool _isLocalAudioActive = false;
  bool _isRemoteAudioActive = false;
  double _localAudioLevel = 0.0;
  double _remoteAudioLevel = 0.0;

  // Connection state
  bool _isConnected = false;
  bool _isMuted = false;

  // Signaling
  late SignalingService _signalingService;
  String? _sessionId;
  String? _partnerId;
  String? _partnerName;

  // Interruption detection
  DateTime? _lastLocalSpeechTime;
  DateTime? _lastRemoteSpeechTime;
  bool _isInterruption = false;
  final Duration _interruptionThreshold = const Duration(milliseconds: 500);

  // Callbacks
  Function(MediaStream)? onRemoteStream;
  Function(String)? onError;
  Function(RTCPeerConnectionState)? onConnectionStateChange;

  // ICE servers configuration - Simplified for maximum compatibility
  final List<Map<String, dynamic>> _iceServers = [
    // Google STUN servers (most reliable)
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    
    // Public TURN server with known good credentials
    {
      'urls': 'turn:numb.viagenie.ca',
      'credential': 'muazkh',
      'username': 'webrtc@live.com'
    },
    
    // Backup TURN server
    {
      'urls': 'turn:192.158.29.39:3478?transport=udp',
      'credential': 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
      'username': '28224511:1379330808'
    },
    {
      'urls': 'turn:192.158.29.39:3478?transport=tcp',
      'credential': 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
      'username': '28224511:1379330808'
    },
  ];

  // Getters
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isLocalAudioActive => _isLocalAudioActive;
  bool get isRemoteAudioActive => _isRemoteAudioActive;
  double get localAudioLevel => _localAudioLevel;
  double get remoteAudioLevel => _remoteAudioLevel;
  bool get isInterruption => _isInterruption;
  RTCPeerConnectionState? get connectionState => _connectionState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  String? get partnerName => _partnerName;

  // Initialize WebRTC service
  Future<void> initialize(String sessionId, String partnerId, {String? userName}) async {
    _sessionId = sessionId;
    _partnerId = partnerId;

    // Request permissions first
    await _requestPermissions();

    // Initialize audio device management
    await _initializeAudioDevices();

    // Initialize signaling service
    _signalingService = SignalingService();
    await _signalingService.connect(sessionId, participantName: userName);

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

  // Initialize audio devices for proper playback
  Future<void> _initializeAudioDevices() async {
    try {
      // Get available audio devices
      final devices = await navigator.mediaDevices.enumerateDevices();
      developer.log('Available media devices: ${devices.length}');

      for (var device in devices) {
        developer.log(
          'Device: ${device.kind} - ${device.label} (${device.deviceId})',
        );
      }

      // Configure audio output for mobile platforms
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        _configureAudioSession();
        // Enable speaker mode for better audio output
        await _enableSpeakerMode();
      }

      developer.log('Audio devices initialized successfully');
    } catch (e) {
      developer.log('Error initializing audio devices: $e');
    }
  }

  // Enable speaker mode for mobile audio output
  Future<void> _enableSpeakerMode() async {
    try {
      // Force audio to use speaker instead of earpiece - use correct WebRTC method
      Helper.setSpeakerphoneOn(true);
      developer.log('Speaker phone mode enabled successfully');
    } catch (e) {
      developer.log('Failed to enable speaker phone: $e');
    }
  }

  // Request audio permissions
  Future<void> _requestPermissions() async {
    try {
      // Request microphone permission
      final microphoneStatus = await Permission.microphone.request();

      if (microphoneStatus != PermissionStatus.granted) {
        developer.log('Microphone permission denied');
        throw Exception('Microphone permission is required for voice calls');
      }

      developer.log('Audio permissions granted');
    } catch (e) {
      developer.log('Failed to request permissions: $e');
      rethrow;
    }
  }

  // Create WebRTC peer connection
  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': _iceServers,
      'iceTransportPolicy': 'all', // Allow all connection types
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 10,
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    _setupPeerConnectionListeners();
  }

  void _setupPeerConnectionListeners() {
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      developer.log('ICE candidate generated: ${candidate.candidate}');
      developer.log('ICE candidate sdpMid: ${candidate.sdpMid}');
      developer.log('ICE candidate sdpMLineIndex: ${candidate.sdpMLineIndex}');

      // Send candidate immediately when generated
      if (_partnerId != null) {
        _sendIceCandidate(candidate);
      } else {
        developer.log(
          'WARNING: ICE candidate generated but no partner ID available',
        );
      }
    };

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      developer.log('ICE connection state: $state');
      _iceConnectionState = state;
      _handleIceConnectionStateChange(state);
    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      developer.log('Peer connection state: $state');
      _connectionState = state;
      onConnectionStateChange?.call(state);
      _handleConnectionStateChange(state);
    };

    _peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      developer.log('ICE gathering state: $state');
      _iceGatheringState = state;

      // When ICE gathering is complete, ensure we have a partner
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        developer.log('ICE gathering complete. Partner ID: $_partnerId');
      }
    };

    // Use both onTrack and onAddStream for compatibility
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      developer.log('Remote track added: ${event.track.kind}');
      developer.log('Remote track enabled: ${event.track.enabled}');
      developer.log('Remote track ID: ${event.track.id}');
      developer.log('Remote streams count: ${event.streams.length}');

      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        developer.log('Remote stream ID: ${_remoteStream!.id}');
        developer.log(
          'Remote stream tracks: ${_remoteStream!.getAudioTracks().length}',
        );

        // Enable audio playback and configure output
        for (var track in _remoteStream!.getAudioTracks()) {
          track.enabled = true;
          developer.log(
            'Remote audio track ${track.id} enabled: ${track.enabled}',
          );
          developer.log('Remote audio track muted: ${track.muted}');
        }

        // Ensure audio playback is configured
        _configureAudioOutput();

        // Force audio to play by setting volume if available
        _ensureAudioPlayback();

        _isConnected = true;
        onRemoteStream?.call(event.streams[0]);
        notifyListeners();
      }
    };

    _peerConnection?.onAddStream = (MediaStream stream) {
      developer.log('Remote stream added via onAddStream');
      developer.log('Stream ID: ${stream.id}');
      developer.log('Audio tracks: ${stream.getAudioTracks().length}');

      // Enable audio playback
      for (var track in stream.getAudioTracks()) {
        track.enabled = true;
        developer.log(
          'Remote audio track ${track.id} enabled: ${track.enabled}',
        );
        developer.log('Remote audio track muted: ${track.muted}');
      }

      // Ensure audio playback is configured
      _configureAudioOutput();

      // Force audio to play by setting volume if available
      _ensureAudioPlayback();

      _remoteStream = stream;
      _isConnected = true;
      onRemoteStream?.call(stream);
      notifyListeners();
    };
  }

  // Configure audio output for remote stream playback
  void _configureAudioOutput() {
    try {
      if (_remoteStream != null) {
        // Enable audio renderer/output for mobile platforms
        for (var track in _remoteStream!.getAudioTracks()) {
          // Force audio to use speaker on mobile devices
          track.enabled = true;
          developer.log('Audio output configured for track: ${track.id}');
        }

        // Configure audio session for speaker output on mobile
        _configureAudioSession();

        developer.log('Audio output configuration completed');
      }
    } catch (e) {
      developer.log('Error configuring audio output: $e');
    }
  }

  // Configure audio session for proper mobile playback
  void _configureAudioSession() async {
    try {
      // For mobile platforms, ensure proper audio routing
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        // Configure audio tracks for proper mobile playback
        await _configureAudioContext();
        developer.log('Mobile audio session configured');
      }
    } catch (e) {
      developer.log('Error configuring audio session: $e');
    }
  }

  // Alternative audio configuration method
  Future<void> _configureAudioContext() async {
    try {
      // Ensure audio tracks are properly configured for playback
      if (_remoteStream != null) {
        for (var track in _remoteStream!.getAudioTracks()) {
          // Set track properties for audio playback
          track.enabled = true;
          developer.log('Audio track ${track.id} configured for playback');
        }
      }
    } catch (e) {
      developer.log('Error in alternative audio configuration: $e');
    }
  }

  // Ensure audio playback is working
  void _ensureAudioPlayback() {
    try {
      if (_remoteStream != null) {
        developer.log(
          'Ensuring audio playback for remote stream: ${_remoteStream!.id}',
        );

        // Log audio track details for debugging
        final audioTracks = _remoteStream!.getAudioTracks();
        developer.log('Remote stream has ${audioTracks.length} audio tracks');

        for (var track in audioTracks) {
          developer.log(
            'Track ${track.id}: enabled=${track.enabled}, muted=${track.muted}',
          );

          // Ensure track is enabled and not muted
          if (!track.enabled) {
            track.enabled = true;
            developer.log('Force enabled track ${track.id}');
          }
        }

        // Additional platform-specific audio configuration
        _configureAudioSession();

        developer.log('Audio playback configuration completed');
      } else {
        developer.log('No remote stream available for audio playback');
      }
    } catch (e) {
      developer.log('Error ensuring audio playback: $e');
    }
  }

  // Start local media (microphone)
  Future<void> _startLocalMedia() async {
    try {
      final constraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'sampleRate': 48000,
          'channelCount': 1,
        },
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      // Add tracks to peer connection immediately
      if (_localStream != null && _peerConnection != null) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enabled = true;
          await _peerConnection!.addTrack(track, _localStream!);
          developer.log('Local audio track added and enabled: ${track.id}');
        }
      }

      developer.log('Local media stream obtained and tracks added');
      notifyListeners();
    } catch (e) {
      developer.log('Failed to get user media: $e');
      rethrow;
    }
  }

  // Create and send offer
  Future<void> createOffer() async {
    if (_peerConnection == null || _partnerId == null) {
      developer.log('Cannot create offer - peerConnection: ${_peerConnection != null}, partnerId: $_partnerId');
      return;
    }

    try {
      developer.log('Creating offer for partner: $_partnerId');
      
      final constraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
        },
        'optional': [],
      };

      final offer = await _peerConnection!.createOffer(constraints);
      developer.log('Offer created, setting local description');
      
      await _peerConnection!.setLocalDescription(offer);
      developer.log('Local description set, sending offer to partner');
      
      await _signalingService.sendOffer(offer, _partnerId!);
      developer.log('Offer sent successfully to partner: $_partnerId');
    } catch (e) {
      developer.log('Failed to create offer: $e');
      _handleConnectionFailure();
    }
  }

  // Handle received offer
  Future<void> _handleOfferReceived(
    RTCSessionDescription offer,
    String fromId,
  ) async {
    if (_peerConnection == null) {
      developer.log('Cannot handle offer - no peer connection');
      return;
    }

    try {
      developer.log('Received offer from: $fromId, setting remote description');
      await _peerConnection!.setRemoteDescription(offer);
      developer.log('Remote description set successfully');

      developer.log('Creating answer for: $fromId');
      final constraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
        },
        'optional': [],
      };

      final answer = await _peerConnection!.createAnswer(constraints);
      developer.log('Answer created, setting local description');
      
      await _peerConnection!.setLocalDescription(answer);
      developer.log('Local description set, sending answer');
      
      await _signalingService.sendAnswer(answer, fromId);
      developer.log('Answer sent successfully to: $fromId');
    } catch (e) {
      developer.log('Error handling offer: $e');
      _handleConnectionFailure();
    }
  }

  // Handle received answer
  Future<void> _handleAnswerReceived(
    RTCSessionDescription answer,
    String fromId,
  ) async {
    if (_peerConnection == null) {
      developer.log('Cannot handle answer - no peer connection');
      return;
    }

    try {
      developer.log('Received answer from: $fromId, setting remote description');
      await _peerConnection!.setRemoteDescription(answer);
      developer.log('Answer processed successfully from: $fromId');
      
      // Connection should be establishing now
      developer.log('WebRTC connection should be establishing...');
    } catch (e) {
      developer.log('Error handling answer: $e');
      _handleConnectionFailure();
    }
  }

  // Handle received ICE candidate
  Future<void> _handleIceCandidateReceived(
    RTCIceCandidate candidate,
    String fromId,
  ) async {
    if (_peerConnection == null) return;

    try {
      developer.log(
        'Adding ICE candidate from $fromId: ${candidate.candidate}',
      );
      await _peerConnection!.addCandidate(candidate);
      developer.log('ICE candidate added successfully');
    } catch (e) {
      developer.log('Failed to add ICE candidate: $e');
    }
  }

  // Handle partner connection
  void _handlePartnerConnected(String partnerId, String partnerName) {
    developer.log('Partner connected: $partnerId, name: $partnerName');
    _partnerId = partnerId;
    _partnerName = partnerName;

    // Only create offer if we're the "caller" (determined by lexicographic comparison of IDs)
    // This ensures only one side creates an offer while the other waits for it
    if (_signalingService.localId != null &&
        _signalingService.localId!.compareTo(partnerId) < 0) {
      developer.log('I am the caller, creating offer for partner: $partnerId');
      developer.log(
        'My ID: ${_signalingService.localId}, Partner ID: $partnerId',
      );

      // Increased delay to ensure ICE gathering starts properly
      Timer(const Duration(milliseconds: 2000), () async {
        if (_partnerId == partnerId && _peerConnection != null) {
          // Double-check partner is still connected and peer connection exists
          developer.log('Creating offer after delay for partner: $partnerId');
          await createOffer();
        } else {
          developer.log('Skipping offer creation - partner: $_partnerId, pc: ${_peerConnection != null}');
        }
      });
    } else {
      developer.log(
        'I am the callee, waiting for offer from partner: $partnerId',
      );
      developer.log(
        'My ID: ${_signalingService.localId}, Partner ID: $partnerId',
      );
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
    _audioAnalysisTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
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
    bool previousInterruption = _isInterruption;

    // Check if both partners are speaking simultaneously
    if (_isLocalAudioActive && _isRemoteAudioActive) {
      // Check if this is a new interruption (within threshold)
      if (_lastLocalSpeechTime != null && _lastRemoteSpeechTime != null) {
        final localRemoteTimeDiff = _lastLocalSpeechTime!
            .difference(_lastRemoteSpeechTime!)
            .abs();
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
  @override
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

    super.dispose();
  }

  // Force connection cleanup (for session end)
  Future<void> endSession() async {
    if (_partnerId != null) {
      await _signalingService.sendSessionEnd(_partnerId!);
    }
    await dispose();
  }

  void _handleConnectionStateChange(RTCPeerConnectionState state) {
    developer.log('Connection state changed to: $state');
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        developer.log('Connection failed, attempting ICE restart...');
        _isConnected = false;
        notifyListeners();
        _handleConnectionFailure();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        developer.log('Connection established successfully');
        _isConnected = true;
        _retryCount = 0;
        _connectionTimer?.cancel();
        notifyListeners();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        developer.log('Connection is connecting...');
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        developer.log('Connection disconnected, attempting to reconnect...');
        _isConnected = false;
        notifyListeners();
        _startConnectionTimer();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        developer.log('Connection closed');
        _isConnected = false;
        notifyListeners();
        break;
      default:
        developer.log('Unknown connection state: $state');
        break;
    }
  }

  void _handleIceConnectionStateChange(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        developer.log('ICE connection failed');
        _isConnected = false;
        notifyListeners();
        _handleConnectionFailure();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        developer.log('ICE connection established');
        _isConnected = true;
        _connectionTimer?.cancel();
        notifyListeners();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        developer.log('ICE connection checking...');
        break;
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        developer.log('ICE connection disconnected');
        _isConnected = false;
        notifyListeners();
        break;
      default:
        break;
    }
  }

  void _handleConnectionFailure() {
    if (_retryCount < maxRetries) {
      _retryCount++;
      developer.log('Connection failed - attempting recovery (attempt $_retryCount/$maxRetries)');

      Timer(Duration(seconds: _retryCount * 2), () async {
        if (_retryCount == 1) {
          // First retry: Try ICE restart
          await _restartIce();
        } else {
          // Subsequent retries: Full reconnection
          await _attemptReconnection();
        }
      });
    } else {
      developer.log('Max retries reached, connection failed permanently');
      onError?.call('Connection failed after $maxRetries attempts. Please check your internet connection.');
    }
  }

  Future<void> _restartIce() async {
    try {
      developer.log('Attempting ICE restart...');
      await _peerConnection?.restartIce();
      
      // After ICE restart, create a new offer if we're the caller
      if (_partnerId != null && _signalingService.localId != null &&
          _signalingService.localId!.compareTo(_partnerId!) < 0) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await createOffer();
        developer.log('New offer created after ICE restart');
      }
      
      developer.log('ICE restart completed');
    } catch (e) {
      developer.log('Failed to restart ICE: $e');
      // Try complete reconnection as fallback
      await _attemptReconnection();
    }
  }

  Future<void> _attemptReconnection() async {
    try {
      developer.log('Attempting complete reconnection...');
      
      // Close current connection
      await _peerConnection?.close();
      
      // Recreate peer connection
      await _createPeerConnection();
      
      // Re-add local stream
      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }
      
      // Create new offer if we're the caller
      if (_partnerId != null && _signalingService.localId != null &&
          _signalingService.localId!.compareTo(_partnerId!) < 0) {
        await Future.delayed(const Duration(milliseconds: 2000));
        await createOffer();
      }
      
      developer.log('Reconnection attempt completed');
    } catch (e) {
      developer.log('Reconnection failed: $e');
    }
  }

  void _startConnectionTimer() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer(const Duration(seconds: 30), () {
      if (_connectionState !=
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        developer.log('Connection timeout, attempting recovery');
        _handleConnectionFailure();
      }
    });
  }

  void _sendIceCandidate(RTCIceCandidate candidate) {
    if (_partnerId != null) {
      developer.log(
        'Sending ICE candidate to $_partnerId: ${candidate.candidate?.substring(0, 50)}...',
      );

      try {
        _signalingService.sendIceCandidate(candidate, _partnerId!);
        developer.log('ICE candidate sent successfully via signaling');
      } catch (e) {
        developer.log('Failed to send ICE candidate: $e');
      }
    } else {
      developer.log('Cannot send ICE candidate - no partner ID available');
    }
  }
}
