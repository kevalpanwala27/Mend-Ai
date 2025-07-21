import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/gradient_button.dart';
import '../resolution/post_resolution_screen.dart';

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.interruptionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(
                Icons.person_off_rounded,
                color: AppTheme.interruptionColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            const Text('Partner Left Session'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your partner has left the session. Would you like to continue alone or leave as well?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: GradientButton(
                    text: 'Stay',
                    icon: Icons.stay_current_portrait_rounded,
                    isSecondary: true,
                    height: 48,
                    fontSize: 14,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.interruptionColor,
                          Color(0xFFE57373),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.interruptionColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.exit_to_app_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: AppTheme.spacingXS),
                          Text(
                            'Leave Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppTheme.spacingL),
        contentPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingL,
          AppTheme.spacingM,
          AppTheme.spacingL,
          0,
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingL,
          AppTheme.spacingL,
          AppTheme.spacingL,
          AppTheme.spacingM,
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.interruptionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppTheme.interruptionColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            const Text('End Session?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to end this session? Any progress and conversation history will be lost.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: GradientButton(
                    text: 'Cancel',
                    icon: Icons.close_rounded,
                    isSecondary: true,
                    height: 48,
                    fontSize: 14,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.interruptionColor,
                          Color(0xFFE57373),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.interruptionColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: AppTheme.spacingXS),
                          Text(
                            'End Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppTheme.spacingL),
        contentPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingL,
          AppTheme.spacingM,
          AppTheme.spacingL,
          0,
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingL,
          AppTheme.spacingL,
          AppTheme.spacingL,
          AppTheme.spacingM,
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _showCompleteSessionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppTheme.successGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            const Text('Complete Session?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great work! You\'ve had a meaningful conversation. Would you like to complete this session and see your communication insights?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: GradientButton(
                    text: 'Continue',
                    icon: Icons.chat_rounded,
                    isSecondary: true,
                    height: 48,
                    fontSize: 14,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.successGreen,
                          Color(0xFF66BB6A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.successGreen.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: AppTheme.spacingXS),
                          Text(
                            'Complete & Review',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(AppTheme.spacingL),
        contentPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingL,
          AppTheme.spacingM,
          AppTheme.spacingL,
          0,
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingL,
          AppTheme.spacingL,
          AppTheme.spacingL,
          AppTheme.spacingM,
        ),
      ),
    );
    
    if (result == true && mounted) {
      // Navigate to post-resolution flow
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const PostResolutionScreen(),
        ),
      );
    }
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
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
            ).createShader(bounds),
            child: const Text(
              'Voice Session',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.interruptionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppTheme.interruptionColor,
                size: 20,
              ),
            ),
            onPressed: () async {
              final shouldExit = await _showExitConfirmation();
              if (shouldExit && mounted) {
                final appState = Provider.of<FirebaseAppState>(context, listen: false);
                await appState.leaveCurrentSession();
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // Complete Session Button
            Container(
              margin: const EdgeInsets.only(right: AppTheme.spacingS),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                ),
                onPressed: () => _showCompleteSessionDialog(),
              ),
            ),
            // Session Code Display
            Container(
              margin: const EdgeInsets.only(right: AppTheme.spacingM),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code_rounded,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    widget.sessionCode,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.background,
              Color(0xFFF8F9FA),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              children: [
                // Voice Control Card
                AnimatedCard(
                  child: Column(
                    children: [
                      // Status Indicator
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingM,
                          horizontal: AppTheme.spacingL,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isListening
                                ? [AppTheme.interruptionColor.withValues(alpha: 0.1), AppTheme.interruptionColor.withValues(alpha: 0.05)]
                                : [AppTheme.primary.withValues(alpha: 0.1), AppTheme.primary.withValues(alpha: 0.05)],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(AppTheme.spacingS),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? AppTheme.interruptionColor
                                    : AppTheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: _isListening
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.interruptionColor.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isListening ? 'Listening...' : 'Ready to listen',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: _isListening
                                          ? AppTheme.interruptionColor
                                          : AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_isListening && _recognizedText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: AppTheme.spacingXS),
                                      child: Text(
                                        _recognizedText,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                
                // Messages Area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _messagesRef.orderBy('timestamp').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          );
                        }
                        
                        final docs = snapshot.data!.docs;
                        
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.spacingL),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 48,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingM),
                                Text(
                                  'Start the conversation',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                Text(
                                  'Tap the mic or type to begin your guided session',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
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
                            
                            if (msg.isAI) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingL,
                                      vertical: AppTheme.spacingM,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.accent,
                                          Color(0xFF4DB6AC),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accent.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.psychology_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: AppTheme.spacingS),
                                        Flexible(
                                          child: Text(
                                            msg.text,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
                              child: Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingM,
                                    vertical: AppTheme.spacingS,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isMe
                                        ? const LinearGradient(
                                            colors: [
                                              AppTheme.primary,
                                              Color(0xFF29B6F6),
                                            ],
                                          )
                                        : null,
                                    color: isMe ? null : AppTheme.cardBackground,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(AppTheme.radiusM),
                                      topRight: const Radius.circular(AppTheme.radiusM),
                                      bottomLeft: isMe
                                          ? const Radius.circular(AppTheme.radiusM)
                                          : const Radius.circular(AppTheme.radiusXS),
                                      bottomRight: isMe
                                          ? const Radius.circular(AppTheme.radiusXS)
                                          : const Radius.circular(AppTheme.radiusM),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isMe ? AppTheme.primary : Colors.black)
                                            .withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : AppTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                
                // Input Area
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Voice Button
                      GestureDetector(
                        onTap: _isListening ? _stopListening : _startListening,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _isListening
                                ? LinearGradient(
                                    colors: [
                                      AppTheme.interruptionColor,
                                      AppTheme.interruptionColor.withValues(alpha: 0.8),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [
                                      AppTheme.gradientStart,
                                      AppTheme.gradientEnd,
                                    ],
                                  ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? AppTheme.interruptionColor : AppTheme.primary)
                                    .withValues(alpha: 0.3),
                                blurRadius: _isListening ? 12 : 8,
                                offset: const Offset(0, 4),
                                spreadRadius: _isListening ? 2 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: AppTheme.spacingM),
                      
                      // Text Input
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(AppTheme.radiusL),
                            border: Border.all(
                              color: AppTheme.borderColor,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingM,
                                vertical: AppTheme.spacingM,
                              ),
                            ),
                            onSubmitted: (_) => _handleSend(),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: AppTheme.spacingM),
                      
                      // Send Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: _controller.text.trim().isNotEmpty
                              ? const LinearGradient(
                                  colors: [
                                    AppTheme.gradientStart,
                                    AppTheme.gradientEnd,
                                  ],
                                )
                              : null,
                          color: _controller.text.trim().isEmpty
                              ? AppTheme.borderColor
                              : null,
                          shape: BoxShape.circle,
                          boxShadow: _controller.text.trim().isNotEmpty
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _controller.text.trim().isNotEmpty ? _handleSend : null,
                          color: _controller.text.trim().isNotEmpty
                              ? Colors.white
                              : AppTheme.textTertiary,
                          iconSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
