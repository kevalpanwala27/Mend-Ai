import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class WebRTCCallScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;
  final bool isCaller;
  const WebRTCCallScreen({
    super.key,
    required this.sessionCode,
    required this.userId,
    required this.isCaller,
  });

  @override
  State<WebRTCCallScreen> createState() => _WebRTCCallScreenState();
}

class _WebRTCCallScreenState extends State<WebRTCCallScreen> with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _micOn = true;
  bool _videoOn = true;
  bool _callActive = false;
  List<String> _participants = [];
  Map<String, RTCPeerConnection> _peerConnections = {};
  Map<String, bool> _remoteConnected = {};
  Map<String, MediaStream> _remoteStreams = {};
  Map<String, RTCVideoRenderer> _remoteRenderers = {};
  late final String _selfId;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selfId = widget.userId;
    _localRenderer.initialize();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _pulseController.repeat(reverse: true);
    _fadeController.forward();
    _initGroupCall();
  }

  Future<void> _initGroupCall() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _videoOn,
    });
    _localRenderer.srcObject = _localStream;
    // Listen for participant list
    _firestore
        .collection('sessions')
        .doc(widget.sessionCode)
        .snapshots()
        .listen((doc) async {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data['participants'] != null) {
            final List<String> newParticipants = List<String>.from(
              data['participants'],
            );
            if (newParticipants.length != _participants.length) {
              setState(() => _participants = newParticipants);
              await _setupConnections();
            }
          }
        });
  }

  Future<void> _setupConnections() async {
    for (final otherId in _participants) {
      if (otherId == _selfId) continue;
      if (_peerConnections.containsKey(otherId)) continue;
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      });
      pc.addStream(_localStream!);
      pc.onIceCandidate = (candidate) {
        if (candidate != null) {
          _signalingDoc(
            otherId,
            _selfId,
          ).collection('signals').add({'candidate': candidate.toMap()});
        }
      };
      pc.onAddStream = (stream) async {
        setState(() {
          _remoteConnected[otherId] = true;
          _remoteStreams[otherId] = stream;
        });
        // Setup remote video renderer
        if (!_remoteRenderers.containsKey(otherId)) {
          final renderer = RTCVideoRenderer();
          await renderer.initialize();
          renderer.srcObject = stream;
          setState(() {
            _remoteRenderers[otherId] = renderer;
          });
        }
      };
      // Listen for remote ICE candidates
      _signalingDoc(_selfId, otherId).collection('signals').snapshots().listen((
        snapshot,
      ) {
        for (final snap in snapshot.docs) {
          final data = snap.data() as Map<String, dynamic>?;
          if (data == null) continue;
          if (data['candidate'] != null) {
            pc.addCandidate(
              RTCIceCandidate(
                data['candidate']['candidate'],
                data['candidate']['sdpMid'],
                data['candidate']['sdpMLineIndex'],
              ),
            );
          }
        }
      });
      // Listen for offer/answer
      _signalingDoc(_selfId, otherId).collection('signals').snapshots().listen((
        snapshot,
      ) async {
        for (final snap in snapshot.docs) {
          final data = snap.data() as Map<String, dynamic>?;
          if (data == null) continue;
          if (data['offer'] != null && !widget.isCaller) {
            await pc.setRemoteDescription(
              RTCSessionDescription(
                data['offer']['sdp'],
                data['offer']['type'],
              ),
            );
            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            await _signalingDoc(
              otherId,
              _selfId,
            ).collection('signals').add({'answer': answer.toMap()});
            setState(() => _callActive = true);
          } else if (data['answer'] != null && widget.isCaller) {
            await pc.setRemoteDescription(
              RTCSessionDescription(
                data['answer']['sdp'],
                data['answer']['type'],
              ),
            );
            setState(() => _callActive = true);
          }
        }
      });
      // Initiate call if caller
      if (widget.isCaller && _selfId.compareTo(otherId) < 0) {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        await _signalingDoc(
          otherId,
          _selfId,
        ).collection('signals').add({'offer': offer.toMap()});
      }
      _peerConnections[otherId] = pc;
    }
  }

  DocumentReference _signalingDoc(String a, String b) {
    final docId = a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
    return _firestore
        .collection('sessions')
        .doc(widget.sessionCode)
        .collection('webrtc')
        .doc(docId);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _localRenderer.dispose();
    _localStream?.dispose();
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }

  void _toggleMic() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() => _micOn = audioTrack.enabled);
    }
  }

  void _toggleVideo() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().isNotEmpty
          ? _localStream!.getVideoTracks().first
          : null;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
        setState(() => _videoOn = videoTrack.enabled);
      } else if (!_videoOn) {
        // Add video track if not present
        final newStream = await navigator.mediaDevices.getUserMedia({
          'video': true,
        });
        final newTrack = newStream.getVideoTracks().first;
        await _localStream!.addTrack(newTrack);
        _localRenderer.srcObject = _localStream;
        setState(() => _videoOn = true);
      }
    }
  }

  void _hangUp() {
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Video Call',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Status indicator
            if (!_callActive) _buildConnectingIndicator(),
            
            // Video grid
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: _buildVideoGrid(),
              ),
            ),
            
            // Controls
            _buildControlPanel(),
            
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectingIndicator() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                color: AppTheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'Connecting...',
            style: TextStyle(
              color: AppTheme.secondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoGrid() {
    final remoteCount = _remoteRenderers.length;
    
    if (remoteCount == 0) {
      // Only local video
      return Center(
        child: _buildVideoTile(
          _localRenderer,
          'You',
          isLocal: true,
        ),
      );
    }
    
    return Column(
      children: [
        // Local video (smaller, top-right)
        Align(
          alignment: Alignment.topRight,
          child: Container(
            width: 120.w,
            height: 160.h,
            margin: EdgeInsets.only(bottom: 16.h),
            child: _buildVideoTile(
              _localRenderer,
              'You',
              isLocal: true,
              isSmall: true,
            ),
          ),
        ),
        
        // Remote videos (main grid)
        Expanded(
          child: GridView.count(
            crossAxisCount: remoteCount > 1 ? 2 : 1,
            childAspectRatio: 0.75,
            mainAxisSpacing: 12.w,
            crossAxisSpacing: 12.w,
            children: _remoteRenderers.entries.map((entry) {
              return _buildVideoTile(
                entry.value,
                'Partner',
                isLocal: false,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVideoTile(
    RTCVideoRenderer renderer,
    String label, {
    bool isLocal = false,
    bool isSmall = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmall ? 12.r : 20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmall ? 12.r : 20.r),
        child: Stack(
          children: [
            // Video view
            Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFF2A2A2A),
              child: RTCVideoView(
                renderer,
                mirror: isLocal,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
            
            // Overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            
            // Label
            Positioned(
              bottom: isSmall ? 8.h : 16.h,
              left: isSmall ? 8.w : 16.w,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 8.w : 12.w,
                  vertical: isSmall ? 4.h : 6.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(isSmall ? 8.r : 12.r),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 10.sp : 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            isActive: _micOn,
            onPressed: _toggleMic,
            activeColor: AppTheme.primary,
            inactiveColor: Colors.red,
          ),
          _buildControlButton(
            icon: _videoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            isActive: _videoOn,
            onPressed: _toggleVideo,
            activeColor: AppTheme.primary,
            inactiveColor: Colors.red,
          ),
          _buildControlButton(
            icon: Icons.call_end_rounded,
            isActive: false,
            onPressed: _hangUp,
            activeColor: Colors.red,
            inactiveColor: Colors.red,
            isEndCall: true,
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required Color activeColor,
    required Color inactiveColor,
    bool isEndCall = false,
  }) {
    final color = isActive ? activeColor : inactiveColor;
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56.w,
        height: 56.w,
        decoration: BoxDecoration(
          color: isEndCall 
              ? Colors.red.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            if (isActive || isEndCall)
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24.w,
        ),
      ),
    );
  }
}
