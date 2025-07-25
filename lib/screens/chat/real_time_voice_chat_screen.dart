import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../providers/firebase_app_state.dart';
import '../../services/webrtc_service.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../resolution/post_resolution_screen.dart';
import '../../widgets/mood_checkin_dialog.dart';

class RealTimeVoiceChatScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;

  const RealTimeVoiceChatScreen({
    super.key,
    required this.sessionCode,
    required this.userId,
  });

  @override
  State<RealTimeVoiceChatScreen> createState() => _RealTimeVoiceChatScreenState();
}

class _RealTimeVoiceChatScreenState extends State<RealTimeVoiceChatScreen> with TickerProviderStateMixin {
  // WebRTC service
  late WebRTCService _webrtcService;
  late AIService _aiService;
  
  // Session state
  bool _isConnected = false;
  bool _isInitializing = true;
  String? _partnerId;
  String? _partnerName;
  
  // Voice session state
  bool _isMuted = false;
  bool _showInterruptionWarning = false;
  String _currentAIMessage = "What is the main concern you'd like to address today?";
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

  // AI message examples with context-aware responses
  final List<String> _aiMessages = [
    "What is the main concern you'd like to address today?",
    "Can you reflect on what your partner just shared?",
    "Let's take a deep breath together before moving forward.",
    "How did that make you feel when your partner said that?",
    "Can you both take a moment to appreciate something about each other?",
    "What's one thing you could do differently in this situation?",
    "How can you both work together to resolve this?",
    "Take a moment to validate what your partner is experiencing.",
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
    _webrtcService = WebRTCService();
    _aiService = AIService();
    
    // Set up WebRTC callbacks
    _webrtcService.addListener(_onWebRTCStateChanged);
    
    try {
      // Initialize WebRTC connection
      final appState = Provider.of<FirebaseAppState>(context, listen: false);
      final currentUserId = appState.currentUserId ?? widget.userId;
      
      await _webrtcService.initialize(widget.sessionCode, currentUserId);
      
      setState(() {
        _isInitializing = false;
      });
      
    } catch (e) {
      print('Error initializing WebRTC: $e');
      setState(() {
        _isInitializing = false;
      });
      _showErrorDialog('Failed to initialize voice connection. Please try again.');
    }
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

    _connectionController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
      curve: Curves.easeOutQuart,
    ));

    _aiMessageAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _aiMessageController,
      curve: Curves.easeOutCubic,
    ));

    _warningAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _warningController,
      curve: Curves.easeOutQuart,
    ));

    _connectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _connectionController,
      curve: Curves.easeInOut,
    ));

    _aiMessageController.forward();
  }

  void _onWebRTCStateChanged() {
    if (!mounted) return;
    
    setState(() {
      _isConnected = _webrtcService.isConnected;
    });

    // Handle interruption detection
    if (_webrtcService.isInterruption && !_showInterruptionWarning) {
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
    if (_webrtcService.isLocalAudioActive || _webrtcService.isRemoteAudioActive) {
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
    await _webrtcService.toggleMute();
    setState(() {
      _isMuted = _webrtcService.isMuted;
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
      await _webrtcService.endSession();
      
      // Navigate to post-resolution with session data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PostResolutionScreen(),
        ),
      );
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
      backgroundColor: AppTheme.background,
      body: _isInitializing ? _buildInitializingScreen() : _buildVoiceChatUI(),
    );
  }

  Widget _buildInitializingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
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
          colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_showInterruptionWarning) _buildInterruptionWarning(),
            _buildAIMessageCard(),
            Expanded(child: _buildPartnerViews()),
            _buildControlsFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          // Connection status indicator
          AnimatedBuilder(
            animation: _connectionAnimation,
            builder: (context, child) {
              return Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isConnected ? Colors.green : Colors.red,
                  boxShadow: _isConnected
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.6),
                            blurRadius: 8 * _connectionAnimation.value,
                            spreadRadius: 2 * _connectionAnimation.value,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          
          SizedBox(width: 12.w),
          
          // Session info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mend Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isConnected
                      ? '${_sessionMinutes.toString().padLeft(2, '0')}:${_sessionSeconds.toString().padLeft(2, '0')}'
                      : 'Connecting...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),

          // Mood indicator
          if (_selectedMood != null)
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20.w),
              ),
              child: Text(
                _selectedMood!,
                style: TextStyle(fontSize: 20.sp),
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
                Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Please take turns speaking for better communication',
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
          child: Opacity(
            opacity: _aiMessageAnimation.value.clamp(0.0, 1.0),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
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
                      _currentAIMessage,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
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
    final otherPartner = appState.getOtherPartner();
    
    return Row(
      children: [
        // Partner A (Local User)
        _buildPartnerView(
          name: currentPartner?.name ?? 'You',
          isLocal: true,
          isSpeaking: _webrtcService.isLocalAudioActive,
          audioLevel: _webrtcService.localAudioLevel,
          backgroundColor: AppTheme.partnerAColor.withValues(alpha: 0.1),
          accentColor: AppTheme.partnerAColor,
          isLeft: true,
        ),
        
        // Partner B (Remote Partner)
        _buildPartnerView(
          name: otherPartner?.name ?? 'Partner',
          isLocal: false,
          isSpeaking: _webrtcService.isRemoteAudioActive,
          audioLevel: _webrtcService.remoteAudioLevel,
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
      child: Container(
        margin: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
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
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Profile section
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
                            blurRadius: isSpeaking ? 20 : 10,
                            spreadRadius: isSpeaking ? 5 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person,
                        size: 50.sp,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: 20.h),
              
              // Name
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 8.h),
              
              // Speaking indicator
              Text(
                isSpeaking ? 'Speaking...' : (isLocal && _isMuted) ? 'Muted' : 'Listening',
                style: TextStyle(
                  color: isSpeaking
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 24.h),
              
              // Audio level visualization
              SizedBox(
                height: 80.h,
                child: isSpeaking
                    ? _buildWaveform(accentColor, audioLevel)
                    : _buildInactiveWaveform(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform(Color color, double level) {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (index) {
            final height = (20 + (level * 60) * _waveformAnimation.value * (0.5 + math.Random(index).nextDouble() * 0.5)).h;
            return Container(
              width: 4.w,
              height: height,
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2.w),
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
      padding: EdgeInsets.all(24.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute/Unmute button
          GestureDetector(
            onTap: _toggleMute,
            child: Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: _isMuted
                    ? AppTheme.interruptionColor
                    : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
          ),

          // New AI Prompt button
          GestureDetector(
            onTap: _showNewAIMessage,
            child: Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
          ),

          // End session button
          GestureDetector(
            onTap: _endSession,
            child: Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: AppTheme.interruptionColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.interruptionColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.call_end,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _aiPromptTimer?.cancel();
    _webrtcService.removeListener(_onWebRTCStateChanged);
    _webrtcService.dispose();
    _pulseController.dispose();
    _waveformController.dispose();
    _aiMessageController.dispose();
    _warningController.dispose();
    _connectionController.dispose();
    super.dispose();
  }
}