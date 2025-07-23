import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class CommunicationScoringScreen extends StatefulWidget {
  final String sessionId;
  final String partnerAName;
  final String partnerBName;
  final Map<String, dynamic> partnerAScores;
  final Map<String, dynamic> partnerBScores;

  const CommunicationScoringScreen({
    super.key,
    required this.sessionId,
    required this.partnerAName,
    required this.partnerBName,
    required this.partnerAScores,
    required this.partnerBScores,
  });

  @override
  State<CommunicationScoringScreen> createState() => _CommunicationScoringScreenState();
}

class _CommunicationScoringScreenState extends State<CommunicationScoringScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scoreController;
  late AnimationController _confettiController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scoreAnimation;
  late Animation<double> _confettiAnimation;
  
  bool _showScores = false;
  PageController _pageController = PageController();
  int _currentPage = 0;

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

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startRevealSequence();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoreController,
      curve: Curves.elasticOut,
    ));

    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeInOut,
    ));
  }

  void _startRevealSequence() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeController.forward();
    });
    
    Future.delayed(const Duration(milliseconds: 600), () {
      _slideController.forward();
    });
    
    Future.delayed(const Duration(milliseconds: 1200), () {
      setState(() {
        _showScores = true;
      });
      _scoreController.forward();
      _confettiController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scoreController.dispose();
    _confettiController.dispose();
    _pageController.dispose();
    super.dispose();
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
        widthFactor: _showScores ? (score / 100) : 0,
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

  Widget _buildPartnerCard({
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
          ..._criteria.entries.map((entry) {
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
          }).toList(),
          
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

  Widget _buildConfetti() {
    return AnimatedBuilder(
      animation: _confettiAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ConfettiPainter(_confettiAnimation.value),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                FadeTransition(
                  opacity: _fadeAnimation,
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
                    position: _slideAnimation,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
                        _buildPartnerCard(
                          name: widget.partnerAName,
                          scores: widget.partnerAScores,
                          accentColor: AppTheme.primary,
                          isPartnerA: true,
                        ),
                        _buildPartnerCard(
                          name: widget.partnerBName,
                          scores: widget.partnerBScores,
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
                      width: _currentPage == index ? 24.w : 8.w,
                      height: 8.h,
                      decoration: BoxDecoration(
                        color: _currentPage == index 
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
                  opacity: _fadeAnimation,
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
                                  onPressed: () {
                                    // TODO: Navigate to schedule next session
                                    Navigator.pop(context);
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
            if (_showScores) _buildConfetti(),
          ],
        ),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double animationValue;
  
  ConfettiPainter(this.animationValue);
  
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