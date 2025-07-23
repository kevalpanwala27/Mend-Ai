import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../resolution/post_resolution_screen.dart';
import '../../widgets/mood_checkin_dialog.dart';

class VoiceChatScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;

  const VoiceChatScreen({
    super.key,
    required this.sessionCode,
    required this.userId,
  });

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _ChatMessage {
  final String text;
  final String senderId;
  final bool isAI;
  final Timestamp timestamp;
  _ChatMessage(this.text, this.senderId, this.isAI, this.timestamp);
}

class _VoiceChatScreenState extends State<VoiceChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  bool _hasShownPartnerLeftDialog = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionSubscription;

  // Interruption and speaker tracking
  String? _currentSpeakerId;
  DateTime? _lastMessageTime;
  bool _showInterruptionOverlay = false;
  Timer? _interruptionTimer;
  String? _interruptedPartnerName;

  // Mood check-in
  String? _selectedMood;
  bool _moodCheckedIn = false;

  // New voice session state
  bool _isPartnerASpeaking = false;
  bool _isPartnerBSpeaking = false;
  bool _isMuted = false;
  bool _showInterruptionWarning = false;
  String _currentAIMessage = "What is the main concern you'd like to address today?";
  int _sessionMinutes = 0;
  int _sessionSeconds = 0;
  Timer? _sessionTimer;
  
  // Communication scoring state
  bool _showScoring = false;
  bool _showScoreResults = false;
  int _currentScoringPage = 0;
  PageController _scoringPageController = PageController();
  
  // Mock scoring data - in real app this would come from AI analysis
  final Map<String, dynamic> _partnerAScores = {
    'empathy': 85,
    'listening': 78,
    'reception': 82,
    'clarity': 90,
    'respect': 88,
    'responsiveness': 76,
    'openMindedness': 84,
  };
  
  final Map<String, dynamic> _partnerBScores = {
    'empathy': 79,
    'listening': 85,
    'reception': 77,
    'clarity': 83,
    'respect': 91,
    'responsiveness': 88,
    'openMindedness': 80,
  };
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late AnimationController _aiMessageController;
  late AnimationController _warningController;
  late AnimationController _scoringFadeController;
  late AnimationController _scoringSlideController;
  late AnimationController _scoreAnimationController;
  late AnimationController _confettiController;
  
  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _aiMessageAnimation;
  late Animation<double> _warningAnimation;
  late Animation<double> _scoringFadeAnimation;
  late Animation<Offset> _scoringSlideAnimation;
  late Animation<double> _scoreAnimation;
  late Animation<double> _confettiAnimation;

  // AI message examples
  final List<String> _aiMessages = [
    "What is the main concern you'd like to address today?",
    "Can you reflect on what your partner just shared?",
    "Let's take a deep breath together before moving forward.",
    "How did that make you feel when your partner said that?",
    "Can you both take a moment to appreciate something about each other?",
  ];
  
  // Communication criteria with icons and descriptions
  final Map<String, Map<String, dynamic>> _criteria = {
    'empathy': {
      'name': 'Empathy',
      'icon': Icons.favorite_rounded,
      'description': 'Understanding and validating emotions',
    },
    'listening': {
      'name': 'Listening',
      'icon': Icons.hearing_rounded,
      'description': 'Giving space and avoiding interruptions',
    },
    'reception': {
      'name': 'Reception',
      'icon': Icons.psychology_rounded,
      'description': 'Open and non-defensive reactions',
    },
    'clarity': {
      'name': 'Clarity',
      'icon': Icons.record_voice_over_rounded,
      'description': 'Clear and calm expression',
    },
    'respect': {
      'name': 'Respect',
      'icon': Icons.handshake_rounded,
      'description': 'Kind and non-blaming language',
    },
    'responsiveness': {
      'name': 'Responsiveness',
      'icon': Icons.reply_rounded,
      'description': 'Acknowledging and engaging',
    },
    'openMindedness': {
      'name': 'Open-Mindedness',
      'icon': Icons.lightbulb_rounded,
      'description': 'Considering new perspectives',
    },
  };

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionCode)
          .collection('messages');

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _setupAnimations();
    _startSessionTimer();
    _setupSessionMonitoring();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showMoodCheckinIfNeeded(),
    );
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _aiMessageController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _warningController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveformAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveformController,
      curve: Curves.elasticOut,
    ));

    _aiMessageAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _aiMessageController,
      curve: Curves.easeOutBack,
    ));

    _warningAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _warningController,
      curve: Curves.elasticOut,
    ));
    
    _scoringFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoringFadeController,
      curve: Curves.easeOut,
    ));

    _scoringSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scoringSlideController,
      curve: Curves.easeOutCubic,
    ));

    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoreAnimationController,
      curve: Curves.elasticOut,
    ));

    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeInOut,
    ));

    _aiMessageController.forward();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionSeconds++;
          if (_sessionSeconds >= 60) {
            _sessionSeconds = 0;
            _sessionMinutes++;
          }
        });
      }
    });
  }

  void _togglePartnerSpeaking(bool isPartnerA) {
    setState(() {
      if (isPartnerA) {
        _isPartnerASpeaking = !_isPartnerASpeaking;
        if (_isPartnerASpeaking && _isPartnerBSpeaking) {
          _showInterruptionWarning = true;
          _warningController.forward().then((_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _showInterruptionWarning = false;
                });
                _warningController.reverse();
              }
            });
          });
        }
        if (_isPartnerASpeaking) {
          _pulseController.repeat(reverse: true);
          _waveformController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _waveformController.stop();
        }
      } else {
        _isPartnerBSpeaking = !_isPartnerBSpeaking;
        if (_isPartnerBSpeaking && _isPartnerASpeaking) {
          _showInterruptionWarning = true;
          _warningController.forward().then((_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _showInterruptionWarning = false;
                });
                _warningController.reverse();
              }
            });
          });
        }
        if (_isPartnerBSpeaking) {
          _pulseController.repeat(reverse: true);
          _waveformController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _waveformController.stop();
        }
      }
    });
  }

  void _showNewAIMessage() {
    final random = math.Random();
    setState(() {
      _currentAIMessage = _aiMessages[random.nextInt(_aiMessages.length)];
    });
    _aiMessageController.reset();
    _aiMessageController.forward();
  }

  Future<void> _showMoodCheckinIfNeeded() async {
    if (!_moodCheckedIn) {
      final mood = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MoodCheckinDialog(),
      );
      if (mood != null && mounted) {
        setState(() {
          _selectedMood = mood.emoji;
          _moodCheckedIn = true;
        });
      }
    }
  }

  void _setupSessionMonitoring() {
    // Monitor the active session for status changes using the session code
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<FirebaseAppState>(context, listen: false);
      print('=== SESSION MONITORING SETUP ===');
      print('Session code: ${widget.sessionCode}');
      print('Widget userId: ${widget.userId}');
      print('AppState currentUserId: ${appState.currentUserId}');
      print('AppState currentSession: ${appState.currentSession}');

      _sessionSubscription = FirebaseFirestore.instance
          .collection('sessions')
          .where(FieldPath.documentId, isEqualTo: widget.sessionCode)
          .snapshots()
          .listen(
            (snapshot) {
              print('=== SESSION SNAPSHOT RECEIVED ===');
              print('Session snapshot received: ${snapshot.docs.length} docs');

              if (snapshot.docs.isNotEmpty) {
                final sessionData = snapshot.docs.first.data();
                print('Full session data: $sessionData');

                final participantStatus = Map<String, bool>.from(
                  sessionData['participantStatus'] ?? {},
                );
                print('Participant status: $participantStatus');

                // Get current user's partner ID using the correct format
                final currentUserId = appState.currentUserId;
                print('AppState currentUserId: $currentUserId');

                if (currentUserId != null) {
                  // Check if the OTHER partner has left (not the current user)
                  final otherPartnerId = currentUserId == 'A' ? 'B' : 'A';
                  final otherPartnerActive =
                      participantStatus[otherPartnerId] ?? true;
                  print(
                    'Current user: $currentUserId, Other partner: $otherPartnerId, Other partner active: $otherPartnerActive',
                  );
                  print('Has shown dialog before: $_hasShownPartnerLeftDialog');

                  if (!otherPartnerActive && !_hasShownPartnerLeftDialog) {
                    print('🚨 PARTNER HAS LEFT! Showing dialog...');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _showPartnerLeftDialog();
                      }
                    });
                  } else if (otherPartnerActive) {
                    print('✅ Partner is still active');
                  }
                } else {
                  print('❌ No currentUserId found in appState');
                }
              } else {
                print(
                  '❌ No session document found with ID: ${widget.sessionCode}',
                );
              }
            },
            onError: (error) {
              print('❌ Error in session monitoring: $error');
            },
          );
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
        onDevice: true,
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
    _scrollController.dispose();
    _scoringPageController.dispose();
    _sessionSubscription?.cancel();
    _sessionTimer?.cancel();
    _pulseController.dispose();
    _waveformController.dispose();
    _aiMessageController.dispose();
    _warningController.dispose();
    _scoringFadeController.dispose();
    _scoringSlideController.dispose();
    _scoreAnimationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _sendMessage(String text, {bool isAI = false}) async {
    final appState = Provider.of<FirebaseAppState>(context, listen: false);
    final currentUserId = appState.currentUserId ?? widget.userId;

    await _messagesRef.add({
      'text': text,
      'senderId': isAI ? 'AI' : currentUserId,
      'isAI': isAI,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _sendMessage(text);
      _controller.clear();

      // Auto-scroll to bottom after sending message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

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
            const Expanded(child: Text('Partner Left Session')),
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
                        colors: [AppTheme.interruptionColor, Color(0xFFE57373)],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.interruptionColor.withValues(
                            alpha: 0.3,
                          ),
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

  Widget _buildPartnerView({
    required String name,
    required bool isSpeaking,
    required Color backgroundColor,
    required Color accentColor,
    required bool isLeft,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: isSpeaking
              ? Border.all(
                  color: accentColor,
                  width: 2,
                )
              : null,
          boxShadow: isSpeaking
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              // Profile section
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isSpeaking ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: isSpeaking ? 16 : 8,
                            spreadRadius: isSpeaking ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person,
                        size: 40.sp,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: 12.h),
              
              // Name
              Text(
                name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18.sp,
                ),
              ),
              
              SizedBox(height: 8.h),
              
              // Speaking indicator
              Text(
                isSpeaking ? 'Speaking...' : 'Listening',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSpeaking ? accentColor : AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
              ),
              
              SizedBox(height: 16.h),
              
              // Waveform visualization
              SizedBox(
                height: 60.h,
                child: isSpeaking
                    ? _buildWaveform(accentColor)
                    : _buildInactiveWaveform(),
              ),
              
              SizedBox(height: 16.h),
              
              // Tap to speak button
              GestureDetector(
                onTap: () => _togglePartnerSpeaking(isLeft),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSpeaking 
                        ? accentColor 
                        : accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: accentColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isSpeaking ? 'Stop Speaking' : 'Tap to Speak',
                    style: TextStyle(
                      color: isSpeaking ? Colors.white : accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform(Color color) {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(8, (index) {
            final height = (20 + (math.Random().nextDouble() * 30)) * 
                           _waveformAnimation.value;
            return Container(
              width: 3.w,
              height: height.h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildInactiveWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(8, (index) {
        return Container(
          width: 3.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: AppTheme.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildAIMessageBubble() {
    return ScaleTransition(
      scale: _aiMessageAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppTheme.accent,
              AppTheme.gradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'AI Therapist',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Icon(
                  Icons.volume_up_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 18.sp,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              _currentAIMessage,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterruptionWarning() {
    if (!_showInterruptionWarning) return const SizedBox.shrink();
    
    return ScaleTransition(
      scale: _warningAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppTheme.interruptionColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: AppTheme.interruptionColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: AppTheme.interruptionColor,
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Take turns for healthier communication',
                style: TextStyle(
                  color: AppTheme.interruptionColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            const Expanded(child: Text('End Session?')),
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
          Row(
            children: [
              Expanded(
                flex: 2,
                child: GradientButton(
                  text: '',
                  icon: Icons.close_rounded,
                  isSecondary: true,
                  height: 48,
                  fontSize: 14,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                flex: 3,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.interruptionColor, Color(0xFFE57373)],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.interruptionColor.withValues(
                          alpha: 0.3,
                        ),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.exit_to_app_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'End',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
            const Expanded(child: Text('Complete Session?')),
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
                        colors: [AppTheme.successGreen, Color(0xFF66BB6A)],
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
                            Icons.check_circle,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: AppTheme.spacingXS),
                          Text(
                            'Complete',
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
        MaterialPageRoute(builder: (context) => const PostResolutionScreen()),
      );
    }
  }

  // Helper to get partner color for background
  Color _getSpeakerBackgroundColor(String? speakerId) {
    if (speakerId == null) return AppTheme.background;
    if (speakerId == 'A') {
      return AppTheme.primary.withOpacity(0.10); // light blue
    } else if (speakerId == 'B') {
      return AppTheme.secondary.withOpacity(0.10); // light pink
    } else {
      return AppTheme.accent.withOpacity(0.10); // fallback
    }
  }

  // Helper to get partner name for warning
  String _getPartnerName(String partnerId) {
    final appState = Provider.of<FirebaseAppState>(context, listen: false);
    if (partnerId == 'A') {
      return appState.relationshipData?['partnerA']?['name'] ?? 'Partner A';
    } else if (partnerId == 'B') {
      return appState.relationshipData?['partnerB']?['name'] ?? 'Partner B';
    }
    return 'Partner';
  }

  // Interruption detection logic: call this in the message builder/StreamBuilder
  void _handleNewMessage(_ChatMessage msg) {
    final now = DateTime.now();
    if (_currentSpeakerId != null &&
        msg.senderId != _currentSpeakerId &&
        !msg.isAI &&
        _lastMessageTime != null &&
        now.difference(_lastMessageTime!).inSeconds < 2) {
      // Interruption detected
      setState(() {
        _showInterruptionOverlay = true;
        _interruptedPartnerName = _getPartnerName(_currentSpeakerId!);
      });
      _interruptionTimer?.cancel();
      _interruptionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showInterruptionOverlay = false;
          });
        }
      });
    }
    if (!msg.isAI) {
      _currentSpeakerId = msg.senderId;
      _lastMessageTime = now;
    }
  }

  void _startVoiceCall() {
    // TODO: Implement voice call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice call feature coming soon!'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _joinVoiceCall() {
    // TODO: Implement join voice call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Join voice call feature coming soon!'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }
  
  // Communication scoring methods
  void _showCommunicationScoring() {
    setState(() {
      _showScoring = true;
    });
    _startScoringRevealSequence();
  }
  
  void _startScoringRevealSequence() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _scoringFadeController.forward();
    });
    
    Future.delayed(const Duration(milliseconds: 600), () {
      _scoringSlideController.forward();
    });
    
    Future.delayed(const Duration(milliseconds: 1200), () {
      setState(() {
        _showScoreResults = true;
      });
      _scoreAnimationController.forward();
      _confettiController.forward();
    });
  }
  
  int _calculateOverallScore(Map<String, dynamic> scores) {
    if (scores.isEmpty) return 75; // Default score
    double total = 0;
    scores.forEach((key, value) {
      if (value is num) {
        total += value.toDouble();
      }
    });
    return (total / scores.length).round();
  }

  Widget _buildStarRating(double score) {
    int fullStars = (score / 20).floor();
    bool hasHalfStar = (score % 20) >= 10;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(
            Icons.star_rounded,
            size: 16.sp,
            color: AppTheme.accent,
          );
        } else if (index == fullStars && hasHalfStar) {
          return Icon(
            Icons.star_half_rounded,
            size: 16.sp,
            color: AppTheme.accent,
          );
        } else {
          return Icon(
            Icons.star_outline_rounded,
            size: 16.sp,
            color: AppTheme.borderColor,
          );
        }
      }),
    );
  }

  Widget _buildScoreBar(double score, Color color) {
    return Container(
      height: 8.h,
      width: 100.w,
      decoration: BoxDecoration(
        color: AppTheme.borderColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _showScoreResults ? (score / 100) : 0,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 800 + (score * 10).toInt()),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
  
  String _getStrengths(Map<String, dynamic> scores, String name) {
    final strengths = <String>[];
    scores.forEach((key, value) {
      if (value >= 80) {
        final criteriaName = _criteria[key]?['name'] ?? key;
        strengths.add(criteriaName.toLowerCase());
      }
    });
    
    if (strengths.isEmpty) {
      return 'Great participation in the session! Keep building on your communication skills.';
    }
    
    return 'Excellent ${strengths.join(', ')}! You showed real strength in these areas.';
  }

  String _getImprovements(Map<String, dynamic> scores, String name) {
    final improvements = <String>[];
    scores.forEach((key, value) {
      if (value < 70) {
        final criteriaName = _criteria[key]?['name'] ?? key;
        improvements.add(criteriaName.toLowerCase());
      }
    });
    
    if (improvements.isEmpty) {
      return 'You\'re doing great! Continue practicing active listening and empathy.';
    }
    
    return 'Focus on ${improvements.join(' and ')} in your next conversation. Small improvements make a big difference!';
  }
  
  Widget _buildInsightCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoringPartnerCard({
    required String name,
    required Map<String, dynamic> scores,
    required Color accentColor,
    required bool isPartnerA,
  }) {
    final overallScore = _calculateOverallScore(scores);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Section
          Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  accentColor,
                  accentColor.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              size: 50.sp,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Name
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 24.sp,
              color: AppTheme.textPrimary,
            ),
          ),
          
          SizedBox(height: 8.h),
          
          // Overall Score
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              final displayScore = (_scoreAnimation.value * overallScore).toInt();
              return Column(
                children: [
                  Text(
                    '$displayScore/100',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 36.sp,
                      color: accentColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Communication Score',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              );
            },
          ),
          
          SizedBox(height: 24.h),
          
          // Score Breakdown
          ...(_criteria.entries.map((entry) {
            final criteriaKey = entry.key;
            final criteriaData = entry.value;
            final score = (scores[criteriaKey] ?? 75).toDouble();
            
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      criteriaData['icon'],
                      size: 16.sp,
                      color: accentColor,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          criteriaData['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            _buildScoreBar(score, accentColor),
                            SizedBox(width: 8.w),
                            _buildStarRating(score),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList()),
          
          SizedBox(height: 24.h),
          
          // Strengths
          _buildInsightCard(
            title: 'Strengths',
            content: _getStrengths(scores, name),
            icon: Icons.thumb_up_rounded,
            color: AppTheme.successGreen,
          ),
          
          SizedBox(height: 16.h),
          
          // Improvements
          _buildInsightCard(
            title: 'Growth Areas',
            content: _getImprovements(scores, name),
            icon: Icons.trending_up_rounded,
            color: AppTheme.accent,
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoringConfetti() {
    return AnimatedBuilder(
      animation: _confettiAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ConfettiPainter(_confettiAnimation.value),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildScoringInterface(String partnerAName, String partnerBName) {
    return Stack(
      children: [
        Column(
          children: [
            // Header
            FadeTransition(
              opacity: _scoringFadeAnimation,
              child: Container(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  children: [
                    Text(
                      'Your Communication Insights',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Here\'s how you both did in today\'s session.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16.sp,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Partner Cards
            Expanded(
              child: SlideTransition(
                position: _scoringSlideAnimation,
                child: PageView(
                  controller: _scoringPageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentScoringPage = index;
                    });
                  },
                  children: [
                    _buildScoringPartnerCard(
                      name: partnerAName,
                      scores: _partnerAScores,
                      accentColor: AppTheme.primary,
                      isPartnerA: true,
                    ),
                    _buildScoringPartnerCard(
                      name: partnerBName,
                      scores: _partnerBScores,
                      accentColor: AppTheme.secondary,
                      isPartnerA: false,
                    ),
                  ],
                ),
              ),
            ),
            
            // Page Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [0, 1].map((index) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: _currentScoringPage == index ? 24.w : 8.w,
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: _currentScoringPage == index 
                        ? AppTheme.primary 
                        : AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),
            
            SizedBox(height: 16.h),
            
            // Progress Encouragement
            FadeTransition(
              opacity: _scoringFadeAnimation,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppTheme.gradientStart,
                      AppTheme.gradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Every session helps you grow. Let\'s keep improving together! 💜',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: GradientButton(
                            text: 'Start Reflection',
                            onPressed: () {
                              // TODO: Navigate to reflection screen
                              Navigator.pop(context);
                            },
                            isSecondary: true,
                            height: 48.h,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 48.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                final appState = Provider.of<FirebaseAppState>(context, listen: false);
                                await appState.leaveCurrentSession();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                ),
                              ),
                              child: Text(
                                'Schedule Next Session',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24.h),
          ],
        ),
        
        // Confetti Effect
        if (_showScoreResults) _buildScoringConfetti(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<FirebaseAppState>(context, listen: false);
    final partnerAName = appState.relationshipData?['partnerA']?['name'] ?? 'Alex';
    final partnerBName = appState.relationshipData?['partnerB']?['name'] ?? 'Jamie';
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && mounted) {
          await appState.leaveCurrentSession();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: _showScoring ? _buildScoringInterface(partnerAName, partnerBName) : Column(
            children: [
              // Session Header
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () async {
                            final shouldExit = await _showExitConfirmation();
                            if (shouldExit && mounted) {
                              await appState.leaveCurrentSession();
                              Navigator.of(context).pop();
                            }
                          },
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: AppTheme.textPrimary,
                            size: 24.sp,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              'Mend Session #1',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 18.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Voice-guided session with real-time AI support',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          ),
                          child: Text(
                            '${_sessionMinutes.toString().padLeft(2, '0')}:${_sessionSeconds.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // AI Message Bubble
              _buildAIMessageBubble(),
              
              // Interruption Warning
              _buildInterruptionWarning(),
              
              // Partner Views
              Expanded(
                child: Row(
                  children: [
                    _buildPartnerView(
                      name: partnerAName,
                      isSpeaking: _isPartnerASpeaking,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      accentColor: AppTheme.primary,
                      isLeft: true,
                    ),
                    _buildPartnerView(
                      name: partnerBName,
                      isSpeaking: _isPartnerBSpeaking,
                      backgroundColor: AppTheme.secondary.withOpacity(0.1),
                      accentColor: AppTheme.secondary,
                      isLeft: false,
                    ),
                  ],
                ),
              ),
              
              // Audio Controls
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: _isMuted 
                              ? AppTheme.interruptionColor.withValues(alpha: 0.1)
                              : AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isMuted 
                                ? AppTheme.interruptionColor
                                : AppTheme.primary,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: _isMuted 
                              ? AppTheme.interruptionColor
                              : AppTheme.primary,
                          size: 24.sp,
                        ),
                      ),
                    ),
                    
                    // Need AI Help button
                    GradientButton(
                      text: 'Need AI Help',
                      onPressed: _showNewAIMessage,
                      fontSize: 14.sp,
                      height: 40.h,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                    ),
                    
                    // End Session button
                    GradientButton(
                      text: 'End Session',
                      onPressed: () {
                        _showCommunicationScoring();
                      },
                      isSecondary: true,
                      fontSize: 14.sp,
                      height: 40.h,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double animationValue;
  
  _ConfettiPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = math.Random(42); // Fixed seed for consistent animation
    
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * animationValue;
      final color = [
        AppTheme.primary,
        AppTheme.secondary,
        AppTheme.accent,
        AppTheme.successGreen,
      ][i % 4];
      
      paint.color = color.withValues(alpha: 0.7 * (1 - animationValue * 0.5));
      
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: 4,
        height: 8,
      );
      
      canvas.drawRect(rect, paint);
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
