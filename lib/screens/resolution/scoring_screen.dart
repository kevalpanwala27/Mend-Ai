import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
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

class _ScoringScreenState extends State<ScoringScreen> {
  final AIService _aiService = AIService();
  CommunicationScores? _scores;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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

        return Scaffold(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overall feedback
                          _buildOverallFeedback(),

                          const SizedBox(height: AppTheme.spacingXL),

                          // Current user's scores
                          if (_scores!.partnerScores[appState.currentUserId] !=
                              null)
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: partnerColor.withValues(alpha: 0.2),
          width: 1,
        ),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [partnerColor, partnerColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(
                  Icons.person_rounded,
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
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Communication Score',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: partnerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Text(
                  '$overallScore/100',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: partnerColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          // Score breakdown
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.borderColor, width: 1),
            ),
            child: Column(
              children: [
                _buildScoreRow(
                  'Empathy',
                  score.empathy,
                  Icons.favorite_rounded,
                  partnerColor,
                ),
                _buildScoreRow(
                  'Listening',
                  score.listening,
                  Icons.hearing_rounded,
                  partnerColor,
                ),
                _buildScoreRow(
                  'Reception',
                  score.reception,
                  Icons.psychology_rounded,
                  partnerColor,
                ),
                _buildScoreRow(
                  'Clarity',
                  score.clarity,
                  Icons.record_voice_over_rounded,
                  partnerColor,
                ),
                _buildScoreRow(
                  'Respect',
                  score.respect,
                  Icons.handshake_rounded,
                  partnerColor,
                ),
                _buildScoreRow(
                  'Responsiveness',
                  score.responsiveness,
                  Icons.reply_rounded,
                  partnerColor,
                ),
                _buildScoreRow(
                  'Open-mindedness',
                  score.openMindedness,
                  Icons.lightbulb_rounded,
                  partnerColor,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          // Strengths and improvements
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  'Strengths',
                  score.strengths.join(', '),
                  Icons.thumb_up_rounded,
                  AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildInsightCard(
                  'Growth Areas',
                  score.improvements.join(', '),
                  Icons.trending_up_rounded,
                  AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
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
