import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/firebase_app_state.dart';
import '../../services/ai_service.dart';
import '../../models/communication_session.dart';
import '../../theme/app_theme.dart';
import '../main/home_screen.dart';
import '../main/insights_dashboard_screen.dart';

class ScoringScreen extends StatefulWidget {
  const ScoringScreen({super.key});

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> with TickerProviderStateMixin {
  final AIService _aiService = AIService();
  CommunicationScores? _scores;
  bool _isLoading = true;
  
  late ConfettiController _confettiController;
  late AnimationController _celebrationController;
  late AnimationController _scoreAnimationController;
  late Animation<double> _celebrationAnimation;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _celebrationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeOutBack,
    ));
    
    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoreAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _generateScores();
  }

  Future<void> _generateScores() async {
    final appState = context.read<FirebaseAppState>();
    final currentSession = appState.currentSession;

    debugPrint('=== SCORING DEBUG INFO ===');
    debugPrint('Current session exists: ${currentSession != null}');
    if (currentSession != null) {
      debugPrint('Session ID: ${currentSession.id}');
      debugPrint('Session start time: ${currentSession.startTime}');
      debugPrint('Session end time: ${currentSession.endTime}');
      debugPrint(
        'Session duration: ${currentSession.duration.inMinutes} minutes',
      );
      debugPrint('Session messages count: ${currentSession.messages.length}');
    }
    debugPrint('========================');

    if (currentSession != null) {
      try {
        final scores = await _aiService.analyzeCommunication(currentSession);

        debugPrint('Scores generated successfully!');
        debugPrint(
          'Partner A score: ${scores.partnerScores['A']?.averageScore}',
        );
        debugPrint(
          'Partner B score: ${scores.partnerScores['B']?.averageScore}',
        );

        // End the session with scores
        await appState.endCommunicationSession(
          scores: scores,
          reflection: 'Session completed with AI analysis',
          suggestedActivities: _aiService.getBondingActivities(),
        );

        setState(() {
          _scores = scores;
          _isLoading = false;
        });
        
        // Trigger celebratory animations
        Future.delayed(const Duration(milliseconds: 500), () {
          _celebrationController.forward();
          _scoreAnimationController.forward();
          _confettiController.play();
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('Scoring error details: $e');
        debugPrint('Error type: ${e.runtimeType}');
        _showError('Failed to generate communication scores: ${e.toString()}');
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      debugPrint('No current session available for scoring');
      _showError(
        'No active session found. Please complete a communication session first.',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _returnHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppTheme.spacingL),
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                ),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Analyzing Your Conversation',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Please wait while we generate your communication insights...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppTheme.spacingL),
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.interruptionColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.interruptionColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppTheme.interruptionColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Unable to Generate Scores',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'We encountered an issue analyzing your conversation. Please try again later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _returnHome,
                icon: const Icon(Icons.home_rounded),
                label: const Text('Return Home'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                    vertical: AppTheme.spacingM,
                  ),
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
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        final currentPartner = appState.getCurrentPartner();
        final otherPartner = appState.getOtherPartner();

        return Stack(
          children: [
            Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                title: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                  ).createShader(bounds),
                  child: const Text(
                    'Communication Scores',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.background, Color(0xFFF8F9FA)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _scores == null
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          child: AnimationLimiter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: AnimationConfiguration.toStaggeredList(
                                duration: const Duration(milliseconds: 600),
                                childAnimationBuilder: (widget) => SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(child: widget),
                                ),
                                children: [
                                  // Overall feedback
                                  _buildOverallFeedback(),

                                  const SizedBox(height: AppTheme.spacingXL),

                                  // Current user's scores
                                  if (_scores!.partnerScores[appState.currentUserId] != null)
                                    _buildPartnerScore(
                                      appState.currentUserId ?? 'A',
                                      currentPartner?.name ?? 'You',
                                      _scores!.partnerScores[appState.currentUserId]!,
                                    ),

                                  const SizedBox(height: AppTheme.spacingL),

                                  // Partner's scores (if available)
                                  if (otherPartner != null &&
                                      _scores!.partnerScores[otherPartner.id] != null)
                                    _buildPartnerScore(
                                      otherPartner.id,
                                      otherPartner.name,
                                      _scores!.partnerScores[otherPartner.id]!,
                                    ),

                                  const SizedBox(height: AppTheme.spacingXL),

                                  // Improvement suggestions
                                  _buildImprovementSuggestions(),

                                  const SizedBox(height: AppTheme.spacingXL),

                                  // Action buttons
                                  _buildActionButtons(),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            
            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  AppTheme.primary,
                  AppTheme.secondary,
                  AppTheme.accent,
                  AppTheme.successGreen,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOverallFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Complete!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Here are your communication insights',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: AppTheme.successGreen.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  color: AppTheme.successGreen,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Text(
                    _scores?.overallFeedback ?? 'Great communication session!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerScore(String partnerId, String name, PartnerScore score) {
    final partnerColor = AppTheme.getPartnerColor(partnerId);
    final overallScore = (score.averageScore * 100).round();

    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) => Transform.scale(
        scale: 0.8 + (_celebrationAnimation.value * 0.2),
        child: child,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppTheme.spacingL.w),
        decoration: AppTheme.cardDecoration(
          hasGlow: overallScore >= 80,
          glowColor: partnerColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with radial progress
            Row(
              children: [
                // Radial progress chart
                SizedBox(
                  width: 100.w,
                  height: 100.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      Container(
                        width: 100.w,
                        height: 100.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: partnerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      // Animated progress
                      AnimatedBuilder(
                        animation: _scoreAnimation,
                        builder: (context, child) {
                          return SizedBox(
                            width: 100.w,
                            height: 100.w,
                            child: CircularProgressIndicator(
                              value: score.averageScore * _scoreAnimation.value,
                              strokeWidth: 8.w,
                              backgroundColor: partnerColor.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(partnerColor),
                              strokeCap: StrokeCap.round,
                            ),
                          );
                        },
                      ),
                      // Score in center
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _scoreAnimation,
                            builder: (context, child) {
                              final animatedScore = (overallScore * _scoreAnimation.value).round();
                              return Text(
                                '$animatedScore',
                                style: TextStyle(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w800,
                                  color: partnerColor,
                                ),
                              );
                            },
                          ),
                          Text(
                            '/100',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(width: AppTheme.spacingL.w),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Communication Score',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              partnerColor.withValues(alpha: 0.2),
                              partnerColor.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          _getScoreLabel(score.averageScore),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: partnerColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: AppTheme.spacingL.h),

            // Enhanced radar chart for detailed scores
            Container(
              height: 200.h,
              padding: EdgeInsets.all(16.w),
              decoration: AppTheme.cardDecoration(borderRadius: 16),
              child: _buildRadarChart(score, partnerColor),
            ),

            SizedBox(height: AppTheme.spacingL.h),
            
            // Strengths and improvements with animations
            Row(
              children: [
                Expanded(
                  child: _buildEnhancedInsightCard(
                    'Strengths',
                    score.strengths,
                    Icons.star_rounded,
                    AppTheme.successGreen,
                  ),
                ),
                SizedBox(width: AppTheme.spacingM.w),
                Expanded(
                  child: _buildEnhancedInsightCard(
                    'Growth Areas',
                    score.improvements,
                    Icons.trending_up_rounded,
                    AppTheme.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementSuggestions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent,
                      AppTheme.accent.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
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
                      'Suggestions for Growth',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Areas to focus on for your next session',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: Column(
              children: _scores!.improvementSuggestions.asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final suggestion = entry.value;
                final isLast =
                    index == _scores!.improvementSuggestions.length - 1;

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (!isLast) const SizedBox(height: AppTheme.spacingM),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(
    String label,
    double score,
    IconData icon,
    Color color, {
    bool isLast = false,
  }) {
    final percentage = (score * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusXS),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: score,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            SizedBox(
              width: 35,
              child: Text(
                '$percentage%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        if (!isLast) const SizedBox(height: AppTheme.spacingM),
      ],
    );
  }

  Widget _buildInsightCard(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
              fontSize: 11,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
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
                      'Great Progress!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Continue practicing to strengthen your relationship',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _returnHome,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Return Home'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingM,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InsightsDashboardScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('Insights'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingM,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getScoreLabel(double score) {
    if (score >= 0.9) return 'Excellent';
    if (score >= 0.8) return 'Great';
    if (score >= 0.7) return 'Good';
    if (score >= 0.6) return 'Fair';
    return 'Needs Work';
  }

  Widget _buildRadarChart(PartnerScore score, Color color) {
    final skills = [
      ('Empathy', score.empathy),
      ('Listening', score.listening),
      ('Reception', score.reception),
      ('Clarity', score.clarity),
      ('Respect', score.respect),
      ('Responsiveness', score.responsiveness),
      ('Open-mindedness', score.openMindedness),
    ];

    return Column(
      children: [
        Text(
          'Communication Skills Breakdown',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return Column(
                children: skills.map((skill) {
                  final animatedValue = skill.$2 * _scoreAnimation.value;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80.w,
                          child: Text(
                            skill.$1,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: AppTheme.borderColor,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: animatedValue,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [color, color.withValues(alpha: 0.7)],
                                  ),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${(skill.$2 * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedInsightCard(
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _celebrationAnimation.value) * 30),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: AppTheme.cardDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                ...items.take(3).map((item) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4.w,
                        height: 4.w,
                        margin: EdgeInsets.only(top: 6.h, right: 8.w),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _celebrationController.dispose();
    _scoreAnimationController.dispose();
    super.dispose();
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) {
      return AppTheme.successGreen;
    } else if (score >= 0.6) {
      return AppTheme.primary;
    } else {
      return Colors.orange;
    }
  }
}
