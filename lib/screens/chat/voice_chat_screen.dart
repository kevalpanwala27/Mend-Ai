import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';

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
  final TextEditingController _controller = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  bool _hasShownPartnerLeftDialog = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionSubscription;

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionCode)
          .collection('messages');

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _setupSessionMonitoring();
  }

  void _setupSessionMonitoring() {
    // Monitor the active session for status changes using the session code
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<FirebaseAppState>(context, listen: false);
      print('Setting up session monitoring for session code: ${widget.sessionCode}');
      
      _sessionSubscription = FirebaseFirestore.instance
          .collection('sessions')
          .where(FieldPath.documentId, isEqualTo: widget.sessionCode)
          .snapshots()
          .listen((snapshot) {
        print('Session snapshot received: ${snapshot.docs.length} docs');
        if (snapshot.docs.isNotEmpty) {
          final sessionData = snapshot.docs.first.data();
          final participantStatus = Map<String, bool>.from(sessionData['participantStatus'] ?? {});
          print('Participant status: $participantStatus');
          
          // Get current user's partner ID
          final currentUserId = appState.currentUserId;
          if (currentUserId != null) {
            // Check if the OTHER partner has left (not the current user)
            final otherPartnerId = currentUserId == 'A' ? 'B' : 'A';
            final otherPartnerActive = participantStatus[otherPartnerId] ?? true;
            print('Current user: $currentUserId, Other partner: $otherPartnerId, Other partner active: $otherPartnerActive');
            
            if (!otherPartnerActive && !_hasShownPartnerLeftDialog) {
              print('Partner has left! Showing dialog...');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showPartnerLeftDialog();
              });
            }
          }
        }
      });
    });
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        setState(() {
          _isListening = status == 'listening';
        });
      },
      onError: (error) {
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  Future<void> _startListening() async {
    if (_speechAvailable && !_isListening) {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
            _controller.text = _recognizedText;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    _sessionSubscription?.cancel();
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

  Future<void> _showPartnerLeftDialog() async {
    if (_hasShownPartnerLeftDialog) return;
    _hasShownPartnerLeftDialog = true;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Partner Left'),
        content: const Text(
          'Your partner has left the session. Would you like to leave as well?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave Session'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      final appState = Provider.of<FirebaseAppState>(context, listen: false);
      await appState.leaveCurrentSession();
      Navigator.of(context).pop();
    }
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'Are you sure you want to end this session? Any progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && mounted) {
          final appState = Provider.of<FirebaseAppState>(context, listen: false);
          await appState.leaveCurrentSession();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Voice Session'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldExit = await _showExitConfirmation();
              if (shouldExit && mounted) {
                final appState = Provider.of<FirebaseAppState>(context, listen: false);
                await appState.leaveCurrentSession();
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.gradientStart,
              AppTheme.gradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Session Code: ${widget.sessionCode}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_isListening)
                      Column(
                        children: [
                          const Icon(
                            Icons.mic,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Listening...',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recognizedText.isEmpty ? 'Say something...' : _recognizedText,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    else
                      const Text('Tap the mic to start speaking'),
                  ],
                ),
              ),
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
                GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message or use the mic...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _handleSend(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _controller.text.trim().isNotEmpty ? _handleSend : null,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
        ),
      ),
      ),
    );
  }
}
