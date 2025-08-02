import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../providers/firebase_app_state.dart';
import '../../services/zego_voice_service.dart';
import '../../services/zego_token_service.dart';
import '../../theme/app_theme.dart';
import '../resolution/post_resolution_screen.dart';
import '../../widgets/mood_checkin_dialog.dart';

class ZegoVoiceChatScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;

  const ZegoVoiceChatScreen({
    super.key,
    required this.sessionCode,
    required this.userId,
  });

  @override
  State<ZegoVoiceChatScreen> createState() => _ZegoVoiceChatScreenState();
}

class _ZegoVoiceChatScreenState extends State<ZegoVoiceChatScreen>
    with TickerProviderStateMixin {
  // ZEGO Voice service
  late ZegoVoiceService _zegoService;

  // Session state
  bool _isConnected = false;
  bool _isInitializing = true;

  // Voice session state
  bool _isMuted = false;
  bool _showInterruptionWarning = false;
  String _currentAIMessage =
      "What's something you've been wanting to say but haven't?";
  int _sessionMinutes = 0;
  int _sessionSeconds = 0;
  Timer? _sessionTimer;
  Timer? _aiPromptTimer;

  // Mood check-in
  String? _selectedMood;
  bool _moodCheckedIn = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late AnimationController _aiMessageController;
  late AnimationController _warningController;
  late AnimationController _connectionController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _aiMessageAnimation;
  late Animation<double> _warningAnimation;
  late Animation<double> _connectionAnimation;


  // AI message examples with context-aware responses - emotionally intelligent
  final List<String> _aiMessages = [
    "What's something you've been wanting to say but haven't?",
    "Can you reflect back what you just heard from your partner?",
    "Let's pause and take a breath together — you're both doing great.",
    "What feelings came up for you when you heard that?",
    "Take a moment to appreciate something about your partner right now.",
    "What's one small thing that could help you both feel more connected?",
    "How might you approach this differently if you were your partner?",
    "What would it feel like to really be heard in this moment?",
    "Can you share what you need most from your partner right now?",
    "What's one thing you're grateful for about your relationship?",
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _startSessionTimer();
    _startAIPromptTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showMoodCheckinIfNeeded(),
    );
  }

  void _initializeServices() async {
    _zegoService = ZegoVoiceService();

    // Set up ZEGO callbacks
    _zegoService.addListener(_onZegoStateChanged);
    _zegoService.onError = (error) {
      if (mounted) {
        _showErrorDialog(error);
      }
    };
    _zegoService.onPartnerConnected = () {
      developer.log('Partner connected via ZEGO');
    };
    _zegoService.onPartnerDisconnected = () {
      developer.log('Partner disconnected via ZEGO');
    };

    try {
      // Initialize ZEGO engine
      await _zegoService.initializeEngine();

      // Get user info
      if (!mounted) return;
      final appState = Provider.of<FirebaseAppState>(context, listen: false);
      
      // Generate unique user ID for this session to avoid conflicts
      // Use Firebase UID + timestamp to ensure uniqueness
      final firebaseUid = appState.user?.uid ?? widget.userId;
      final sessionUserId = '${firebaseUid}_${DateTime.now().millisecondsSinceEpoch}';
      
      final currentPartner = appState.getCurrentPartner();
      final userName = currentPartner?.name ?? 'User';

      print('=== STARTING ZEGO VOICE CALL ===');
      print('Room ID: ${widget.sessionCode}');
      print('User ID: $sessionUserId');
      print('User Name: $userName');
      print('DEBUG: appState.user?.uid = ${appState.user?.uid}');
      print('DEBUG: widget.userId = ${widget.userId}');
      print('DEBUG: appState.currentUserId = ${appState.currentUserId}');

      // Get secure token from your backend
      String? token = await ZegoTokenService.generateToken(sessionUserId, widget.sessionCode);
      
      if (token == null) {
        developer.log('WARNING: Could not get token from backend, joining without token');
      } else {
        developer.log('Successfully obtained token from backend');
      }

      // Join voice room with token
      await _zegoService.joinRoom(widget.sessionCode, sessionUserId, userName, token: token);

      setState(() {
        _isInitializing = false;
      });

      developer.log('=== ZEGO VOICE CALL INITIALIZED ===');
    } catch (e) {
      developer.log('CRITICAL ERROR initializing ZEGO: $e');
      setState(() {
        _isInitializing = false;
      });
      _showErrorDialog(
        'Failed to initialize voice connection. Please check your internet connection and try again.',
      );
    }
  }

  // Token fetching is now handled by ZegoTokenService

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

    _connectionController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveformAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _waveformController, curve: Curves.easeOutQuart),
    );

    _aiMessageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _aiMessageController, curve: Curves.easeOutCubic),
    );

    _warningAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _warningController, curve: Curves.easeOutQuart),
    );

    _connectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _connectionController, curve: Curves.easeInOut),
    );

    _aiMessageController.forward();
  }

  void _onZegoStateChanged() {
    if (!mounted) return;

    setState(() {
      _isConnected = _zegoService.isConnected;
    });

    // Handle interruption detection
    if (_zegoService.isInterruption && !_showInterruptionWarning) {
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

    // Handle audio visualization
    if (_zegoService.isLocalAudioActive || _zegoService.isRemoteAudioActive) {
      _pulseController.repeat(reverse: true);
      _waveformController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _waveformController.stop();
    }

    // Connection status animation
    if (_isConnected) {
      _connectionController.forward();
    } else {
      _connectionController.reverse();
    }

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

  void _startAIPromptTimer() {
    // Show new AI prompts every 2-3 minutes to guide conversation
    _aiPromptTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted && _isConnected) {
        _showNewAIMessage();
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

  void _toggleMute() async {
    await _zegoService.toggleMute();
    setState(() {
      _isMuted = _zegoService.isMuted;
    });
  }



  void _endSession() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this voice session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _zegoService.endSession();

      // Navigate to post-resolution with session data
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PostResolutionScreen()),
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitializing ? _buildInitializingScreen() : _buildVoiceChatUI(),
    );
  }

  Widget _buildInitializingScreen() {
    return Container(
      decoration: const BoxDecoration(color: Colors.black),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 24.h),
            Text(
              'Connecting to your partner...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceChatUI() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF16213e),
            Color(0xFF0f3460),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_showInterruptionWarning) _buildInterruptionWarning(),
            SizedBox(height: 20.h),
            _buildAIMessageCard(),
            SizedBox(height: 24.h),
            Expanded(child: _buildPartnerViews()),
            _buildControlsFooter(),
          ],
        ),
      ),
    );
  }

  // ========== OLD UI METHODS (RESTORED WITH WORKING LOGIC) ==========

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Connection status with enhanced styling
          AnimatedBuilder(
            animation: _connectionAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + (_connectionAnimation.value * 0.1),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _isConnected
                        ? AppTheme.successGreen.withValues(alpha: 0.2)
                        : AppTheme.interruptionColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: _isConnected ? AppTheme.successGreen : AppTheme.interruptionColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isConnected ? AppTheme.successGreen : AppTheme.interruptionColor)
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: _isConnected ? AppTheme.successGreen : AppTheme.interruptionColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isConnected ? AppTheme.successGreen : AppTheme.interruptionColor)
                                  .withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _isConnected ? 'Connected' : 'Connecting...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Enhanced session timer with glow
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: AppTheme.primary,
                  size: 16.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  '${_sessionMinutes.toString().padLeft(2, '0')}:${_sessionSeconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterruptionWarning() {
    return AnimatedBuilder(
      animation: _warningAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _warningAnimation.value,
          child: Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.interruptionColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.interruptionColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Let\'s hold space — your partner was still sharing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIMessageCard() {
    return AnimatedBuilder(
      animation: _aiMessageAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _aiMessageAnimation.value) * 50),
          child: Transform.scale(
            scale: 0.8 + (_aiMessageAnimation.value * 0.2),
            child: Opacity(
              opacity: _aiMessageAnimation.value.clamp(0.0, 1.0),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                padding: EdgeInsets.all(20.w),
                decoration: AppTheme.glassmorphicDecoration(borderRadius: 24),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56.w,
                      height: 56.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // AI Orb with pulsing glow
                          AnimatedBuilder(
                            animation: _aiMessageAnimation,
                            builder: (context, child) {
                              return Container(
                                decoration: AppTheme.aiOrbDecoration(
                                  color: AppTheme.aiActive,
                                  isActive: true,
                                  size: 56,
                                ),
                              );
                            },
                          ),
                          // AI Icon
                          Icon(
                            Icons.psychology_rounded,
                            color: AppTheme.textPrimary,
                            size: 28.sp,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6.w,
                                height: 6.w,
                                decoration: BoxDecoration(
                                  color: AppTheme.aiActive,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.aiActive.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Mend AI',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _currentAIMessage,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              letterSpacing: 0.2,
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
        );
      },
    );
  }

  Widget _buildPartnerViews() {
    final appState = Provider.of<FirebaseAppState>(context);
    final currentPartner = appState.getCurrentPartner();

    return Row(
      children: [
        // Partner A (Local User)
        _buildPartnerView(
          name: currentPartner?.name ?? 'You',
          isLocal: true,
          isSpeaking: _zegoService.isLocalAudioActive,
          audioLevel: _zegoService.localAudioLevel,
          backgroundColor: AppTheme.partnerAColor.withValues(alpha: 0.1),
          accentColor: AppTheme.partnerAColor,
          isLeft: true,
        ),

        // Partner B (Remote Partner) - Use ZEGO partner name
        _buildPartnerView(
          name: _zegoService.partnerName ?? 'Partner',
          isLocal: false,
          isSpeaking: _zegoService.isRemoteAudioActive,
          audioLevel: _zegoService.remoteAudioLevel,
          backgroundColor: AppTheme.partnerBColor.withValues(alpha: 0.1),
          accentColor: AppTheme.partnerBColor,
          isLeft: false,
        ),
      ],
    );
  }

  Widget _buildPartnerView({
    required String name,
    required bool isLocal,
    required bool isSpeaking,
    required double audioLevel,
    required Color backgroundColor,
    required Color accentColor,
    required bool isLeft,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSpeaking
              ? backgroundColor.withValues(alpha: 0.3)
              : backgroundColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: isSpeaking
                ? accentColor.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.2),
            width: isSpeaking ? 3 : 1,
          ),
          boxShadow: [
            if (isSpeaking) ...[
              BoxShadow(
                color: accentColor.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 6,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.2),
                blurRadius: 60,
                spreadRadius: 12,
                offset: const Offset(0, 16),
              ),
            ] else ...[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ],
        ),
        child: Container(
          decoration: AppTheme.glassmorphicDecoration(
            borderRadius: AppTheme.radiusXL,
          ),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile section with enhanced glow
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isSpeaking ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100.w,
                          height: 100.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.5),
                                blurRadius: isSpeaking ? 30 : 15,
                                spreadRadius: isSpeaking ? 8 : 2,
                                offset: const Offset(0, 6),
                              ),
                              if (isSpeaking)
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.3),
                                  blurRadius: 50,
                                  spreadRadius: 15,
                                  offset: const Offset(0, 12),
                                ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 48.sp,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16.h),
                  // Name with enhanced typography
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8.h),

                  // Speaking indicator with glow effect
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSpeaking
                          ? accentColor.withValues(alpha: 0.3)
                          : null,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: isSpeaking
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      isSpeaking
                          ? 'Speaking...'
                          : (isLocal && _isMuted)
                              ? 'Muted'
                              : 'Listening',
                      style: TextStyle(
                        color: isSpeaking
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: 20.h),
                  // Enhanced audio level visualization
                  SizedBox(
                    height: 60.h,
                    child: isSpeaking
                        ? _buildEnhancedWaveform(accentColor, audioLevel)
                        : _buildInactiveWaveform(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedWaveform(Color color, double level) {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(8, (index) {
            final height = (15 +
                    (level * 75) *
                        _waveformAnimation.value *
                        (0.3 + math.Random(index).nextDouble() * 0.7))
                .h;
            final opacity = 0.6 + (_waveformAnimation.value * 0.4);

            return Container(
              width: 6.w,
              height: height,
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(3.w),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildInactiveWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        return Container(
          width: 4.w,
          height: 8.h,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2.w),
          ),
        );
      }),
    );
  }

  Widget _buildControlsFooter() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: AppTheme.glassmorphicDecoration(borderRadius: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute/Unmute button
          _buildOldControlButton(
            onTap: _toggleMute,
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            isActive: !_isMuted,
            backgroundColor: _isMuted ? AppTheme.interruptionColor : null,
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),

          // Speaker toggle button (echo warning)
          _buildOldControlButton(
            onTap: () => _zegoService.toggleSpeaker(),
            icon: _zegoService.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
            isActive: _zegoService.isSpeakerOn,
            backgroundColor: _zegoService.isSpeakerOn ? AppTheme.interruptionColor : null,
            tooltip: _zegoService.isSpeakerOn ? 'Speaker On (Use Headphones!)' : 'Enable Speaker (May Echo)',
          ),

          // New AI Prompt button
          _buildOldControlButton(
            onTap: _showNewAIMessage,
            icon: Icons.psychology_rounded,
            isActive: false,
            tooltip: 'New AI Prompt',
          ),

          // End session button
          _buildOldControlButton(
            onTap: _endSession,
            icon: Icons.call_end_rounded,
            isActive: false,
            backgroundColor: AppTheme.interruptionColor,
            tooltip: 'End Session',
          ),
        ],
      ),
    );
  }

  Widget _buildOldControlButton({
    required VoidCallback onTap,
    required IconData icon,
    required bool isActive,
    Color? backgroundColor,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 60.w,
          height: 60.w,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppTheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: backgroundColor != null
                  ? backgroundColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: backgroundColor != null
                    ? backgroundColor.withValues(alpha: 0.4)
                    : AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28.sp),
        ),
      ),
    );
  }










  @override
  void dispose() {
    _sessionTimer?.cancel();
    _aiPromptTimer?.cancel();
    _zegoService.removeListener(_onZegoStateChanged);
    _zegoService.dispose();
    _pulseController.dispose();
    _waveformController.dispose();
    _aiMessageController.dispose();
    _warningController.dispose();
    _connectionController.dispose();
    super.dispose();
  }
}