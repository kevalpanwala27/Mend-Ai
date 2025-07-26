import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class _WebRTCCallScreenState extends State<WebRTCCallScreen> {
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

  @override
  void initState() {
    super.initState();
    _selfId = widget.userId;
    _localRenderer.initialize();
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Video Call')),
      body: Column(
        children: [
          // Local video
          Padding(
            padding: EdgeInsets.all(8.w),
            child: AspectRatio(
              aspectRatio: 1,
              child: RTCVideoView(_localRenderer, mirror: true),
            ),
          ),
          // Remote videos
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: [
                for (final id in _remoteRenderers.keys)
                  Padding(
                    padding: EdgeInsets.all(8.w),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: RTCVideoView(_remoteRenderers[id]!),
                    ),
                  ),
              ],
            ),
          ),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_micOn ? Icons.mic : Icons.mic_off),
                onPressed: _toggleMic,
                iconSize: 36.sp,
              ),
              SizedBox(width: 24.w),
              IconButton(
                icon: Icon(_videoOn ? Icons.videocam : Icons.videocam_off),
                onPressed: _toggleVideo,
                iconSize: 36.sp,
              ),
              SizedBox(width: 24.w),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red),
                onPressed: _hangUp,
                iconSize: 36.sp,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
