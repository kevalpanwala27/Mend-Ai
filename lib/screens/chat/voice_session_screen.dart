import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class VoiceSessionScreen extends StatefulWidget {
  final String partnerAName;
  final String partnerBName;
  final String sessionId;

  const VoiceSessionScreen({
    super.key,
    required this.partnerAName,
    required this.partnerBName,
    required this.sessionId,
  });

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen>
    with TickerProviderStateMixin {
  
  // Session state
  bool _isPartnerASpeaking = false;
  bool _isPartnerBSpeaking = false;
  bool _isMuted = false;
  bool _showInterruptionWarning = false;
  String _currentAIMessage = "What is the main concern you'd like to address today?";
  int _sessionMinutes = 15;
  int _sessionSeconds = 34;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveformController;
  late AnimationController _aiMessageController;
  late AnimationController _warningController;
  
  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _aiMessageAnimation;
  late Animation<double> _warningAnimation;

  // AI message examples
  final List<String> _aiMessages = [
    "What is the main concern you'd like to address today?",
    "Can you reflect on what your partner just shared?",
    "Let's take a deep breath together before moving forward.",
    "How did that make you feel when your partner said that?",
    "Can you both take a moment to appreciate something about each other?",
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSessionTimer();
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

    _aiMessageController.forward();
  }

  void _startSessionTimer() {
    // Simulate session timer
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _sessionSeconds++;
          if (_sessionSeconds >= 60) {
            _sessionSeconds = 0;
            _sessionMinutes++;
          }
        });
        _startSessionTimer();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveformController.dispose();
    _aiMessageController.dispose();
    _warningController.dispose();
    super.dispose();
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
                    color: accentColor.withOpacity(0.3),
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
                            accentColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
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
                        : accentColor.withOpacity(0.1),
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
              color: AppTheme.accent.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.8),
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
          color: AppTheme.interruptionColor.withOpacity(0.1),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
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
                        onPressed: () => Navigator.pop(context),
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
                          color: AppTheme.successGreen.withOpacity(0.1),
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
                    name: widget.partnerAName,
                    isSpeaking: _isPartnerASpeaking,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    accentColor: AppTheme.primary,
                    isLeft: true,
                  ),
                  _buildPartnerView(
                    name: widget.partnerBName,
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
                            ? AppTheme.interruptionColor.withOpacity(0.1)
                            : AppTheme.primary.withOpacity(0.1),
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
                      // TODO: Show end session dialog
                      Navigator.pop(context);
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
    );
  }
}