import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../providers/firebase_app_state.dart';
import '../../services/webrtc_service.dart';

import '../../theme/app_theme.dart';

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
  State<RealTimeVoiceChatScreen> createState() =>
      _RealTimeVoiceChatScreenState();
}

class _RealTimeVoiceChatScreenState extends State<RealTimeVoiceChatScreen>
    with TickerProviderStateMixin {
  // WebRTC service
  late WebRTCService _webrtcService;
  
  // Audio renderers for WebRTC streams
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

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
    _initializeRenderers();
    _initializeServices();
    _setupAnimations();
    _startSessionTimer();
    _startAIPromptTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showMoodCheckinIfNeeded(),
    );
  }

  void _initializeRenderers() async {
    await _remoteRenderer.initialize();
    
    // Configure renderer for audio playback on mobile
    try {
      _remoteRenderer.muted = false;
      print('Audio renderer initialized for audio playback');
    } catch (e) {
      print('Error configuring audio renderer: $e');
    }
  }

  // Attach remote stream to renderer for audio playback
  void _attachRemoteStream() async {
    try {
      final remoteStream = _webrtcService.remoteStream;
      if (remoteStream != null) {
        _remoteRenderer.srcObject = remoteStream;
        print('Remote stream attached to renderer: ${remoteStream.id}');
        
        // Enable audio tracks and ensure they're not muted
        for (var track in remoteStream.getAudioTracks()) {
          track.enabled = true;
          print('Audio track ${track.id} enabled: ${track.enabled}, muted: ${track.muted}');
        }
        
        // Force update the renderer
        setState(() {});
        print('Audio renderer updated with remote stream');
      }
    } catch (e) {
      print('Error attaching remote stream: $e');
    }
  }

  void _initializeServices() async {
    _webrtcService = WebRTCService();

    // Set up WebRTC callbacks
    _webrtcService.addListener(_onWebRTCStateChanged);

    try {
      // Initialize WebRTC connection
      final appState = Provider.of<FirebaseAppState>(context, listen: false);
      final currentUserId = appState.currentUserId ?? widget.userId;
      final currentPartner = appState.getCurrentPartner();
      final userName = currentPartner?.name ?? 'User';

      await _webrtcService.initialize(widget.sessionCode, currentUserId, userName: userName);

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      print('Error initializing WebRTC: $e');
      setState(() {
        _isInitializing = false;
      });
      _showErrorDialog(
        'Failed to initialize voice connection. Please try again.',
      );
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

  void _onWebRTCStateChanged() {
    if (!mounted) return;

    setState(() {
      _isConnected = _webrtcService.isConnected;
    });

    // Attach remote stream to renderer for audio playback (only once)
    if (_webrtcService.remoteStream != null && _remoteRenderer.srcObject == null) {
      _attachRemoteStream();
    }

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
    if (_webrtcService.isLocalAudioActive ||
        _webrtcService.isRemoteAudioActive) {
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

  void _reconnect() async {
    try {
      print('Manual reconnect triggered');
      
      // Show loading indicator
      setState(() {
        _isInitializing = true;
      });
      
      // Force reconnection
      await _webrtcService.dispose();
      
      // Reinitialize WebRTC
      _initializeServices();
      
      print('Manual reconnect completed');
    } catch (e) {
      print('Error during manual reconnect: $e');
      setState(() {
        _isInitializing = false;
      });
    }
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
        MaterialPageRoute(builder: (context) => const PostResolutionScreen()),
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
      decoration: const BoxDecoration(color: Colors.black),
      child: SafeArea(
        child: Stack(
          children: [
            // Hidden RTCVideoView for audio playback
            Positioned(
              left: -1000,
              top: -1000,
              child: SizedBox(
                width: 1,
                height: 1,
                child: RTCVideoView(_remoteRenderer, mirror: false),
              ),
            ),
            Column(
              children: [
                _buildHeader(),
                if (_showInterruptionWarning) _buildInterruptionWarning(),
                _buildAIMessageCard(),
                Expanded(child: _buildPartnerViews()),
                _buildControlsFooter(),
              ],
            ),
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
              child: Text(_selectedMood!, style: TextStyle(fontSize: 20.sp)),
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
                    Container(
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
                        mainAxisSize:
                            MainAxisSize.min, // Fix potential overflow
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
          isSpeaking: _webrtcService.isLocalAudioActive,
          audioLevel: _webrtcService.localAudioLevel,
          backgroundColor: AppTheme.partnerAColor.withValues(alpha: 0.1),
          accentColor: AppTheme.partnerAColor,
          isLeft: true,
        ),

        // Partner B (Remote Partner) - Use WebRTC partner name
        _buildPartnerView(
          name: _webrtcService.partnerName ?? 'Partner',
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
            padding: EdgeInsets.all(20.w), // Reduced padding
            child: SingleChildScrollView(
              // Added scrollable container
              child: Column(
                mainAxisSize: MainAxisSize.min, // Fix the overflow
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile section with enhanced glow
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isSpeaking ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100.w, // Reduced size
                          height: 100.w, // Reduced size
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
                            size: 48.sp, // Reduced size
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16.h), // Reduced spacing
                  // Name with enhanced typography
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp, // Reduced font size
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
                        fontSize: 12.sp, // Reduced font size
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: 20.h), // Reduced spacing
                  // Enhanced audio level visualization
                  SizedBox(
                    height: 60.h, // Reduced height
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
            final height =
                (15 +
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
          _buildControlButton(
            onTap: _toggleMute,
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            isActive: !_isMuted,
            backgroundColor: _isMuted ? AppTheme.interruptionColor : null,
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),

          // New AI Prompt button
          _buildControlButton(
            onTap: _showNewAIMessage,
            icon: Icons.psychology_rounded,
            isActive: false,
            tooltip: 'New AI Prompt',
          ),

          // Reconnect button (for connection issues)
          _buildControlButton(
            onTap: _reconnect,
            icon: Icons.refresh_rounded,
            isActive: false,
            tooltip: 'Reconnect',
          ),

          // End session button
          _buildControlButton(
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

  Widget _buildControlButton({
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
          width: 70.w,
          height: 70.w,
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
          child: Icon(icon, color: Colors.white, size: 32.sp),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _aiPromptTimer?.cancel();
    _webrtcService.removeListener(_onWebRTCStateChanged);
    _webrtcService.dispose();
    _remoteRenderer.dispose();
    _pulseController.dispose();
    _waveformController.dispose();
    _aiMessageController.dispose();
    _warningController.dispose();
    _connectionController.dispose();
    super.dispose();
  }
}
