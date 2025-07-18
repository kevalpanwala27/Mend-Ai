import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

const String agoraAppId = 'dd07721ab911427594816a336df09b95';

class VoiceSessionScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;

  const VoiceSessionScreen({
    Key? key,
    required this.sessionCode,
    required this.userId,
  }) : super(key: key);

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _ChatMessage {
  final String text;
  final String senderId;
  final bool isAI;
  final Timestamp timestamp;
  _ChatMessage(this.text, this.senderId, this.isAI, this.timestamp);
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen> {
  bool _connected = false;
  int? _localUid;
  final List<int> _remoteUids = [];
  final TextEditingController _controller = TextEditingController();
  late final RtcEngine _engine;

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionCode)
          .collection('messages');

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone].request();
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          setState(() {
            _connected = true;
            _localUid = conn.localUid;
          });
        },
        onUserJoined: (conn, remoteUid, elapsed) {
          setState(() {
            _remoteUids.add(remoteUid);
          });
        },
        onUserOffline: (conn, remoteUid, reason) {
          setState(() {
            _remoteUids.remove(remoteUid);
          });
        },
        onLeaveChannel: (conn, stats) {
          setState(() {
            _connected = false;
            _localUid = null;
            _remoteUids.clear();
          });
        },
      ),
    );
  }

  Future<void> _joinVoiceChannel() async {
    await _engine.joinChannel(
      token: '', // For demo, no token. For production, use a token server.
      channelId: widget.sessionCode,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _leaveVoiceChannel() async {
    await _engine.leaveChannel();
  }

  @override
  void dispose() {
    _engine.release();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage(String text, {bool isAI = false}) async {
    await _messagesRef.add({
      'text': text,
      'senderId': isAI ? 'AI' : widget.userId,
      'isAI': isAI,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _sendMessage(text);
      _controller.clear();
      // Simulate AI prompt after user message
      Future.delayed(const Duration(milliseconds: 600), () {
        _sendMessage(_getAIPrompt(text), isAI: true);
      });
    }
  }

  String _getAIPrompt(String userMsg) {
    final prompts = [
      "How do you feel about what your partner just said?",
      "Can you help your partner understand your perspective?",
      "What would you need to feel heard in this situation?",
      "What’s one thing you appreciate about your partner?",
      "How can you both work together to address this challenge?",
    ];
    return prompts[userMsg.length % prompts.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Voice Session')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text('Session Code: ${widget.sessionCode}'),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: Icon(_connected ? Icons.call_end : Icons.call),
                  label: Text(
                    _connected ? 'Disconnect Voice' : 'Connect Voice',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _connected ? Colors.red : Colors.green,
                  ),
                  onPressed: _connected
                      ? _leaveVoiceChannel
                      : _joinVoiceChannel,
                ),
                const SizedBox(width: 16),
                if (_connected)
                  Text(
                    'Connected! Uid: $_localUid, Peers: ${_remoteUids.length}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesRef.orderBy('timestamp').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final msg = _ChatMessage(
                        data['text'] ?? '',
                        data['senderId'] ?? '',
                        data['isAI'] ?? false,
                        data['timestamp'] ?? Timestamp.now(),
                      );
                      final isMe = msg.senderId == widget.userId;
                      return Align(
                        alignment: msg.isAI
                            ? Alignment.center
                            : isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: msg.isAI
                                ? Colors.green[100]
                                : isMe
                                ? Colors.blue[100]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(msg.text),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message... (demo)',
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSend,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Voice chat is now integrated above
          ],
        ),
      ),
    );
  }
}
