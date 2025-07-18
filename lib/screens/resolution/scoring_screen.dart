import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';
import '../../models/communication_session.dart';
import '../../theme/app_theme.dart';
import '../main/home_screen.dart';

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
    final appState = context.read<AppState>();
    final currentSession = appState.currentSession;

    if (currentSession != null) {
      try {
        final scores = await _aiService.analyzeCommunication(currentSession);

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
        _showError('Failed to generate communication scores');
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      _showError('No active session found');
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final currentPartner = appState.getCurrentPartner();
        final otherPartner = appState.getOtherPartner();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Communication Scores'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(icon: const Icon(Icons.home), onPressed: _returnHome),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analyzing your conversation...'),
                    ],
                  ),
                )
              : _scores == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to generate scores',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try again later',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _returnHome,
                        child: const Text('Return Home'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overall feedback
                      _buildOverallFeedback(),

                      const SizedBox(height: 32),

                      // Partner scores
                      _buildPartnerScore(
                        'A',
                        currentPartner?.name ?? 'Partner A',
                        _scores!.partnerScores['A']!,
                      ),

                      const SizedBox(height: 24),

                      _buildPartnerScore(
                        'B',
                        otherPartner?.name ?? 'Partner B',
                        _scores!.partnerScores['B']!,
                      ),

                      const SizedBox(height: 32),

                      // Improvement suggestions
                      _buildImprovementSuggestions(),

                      const SizedBox(height: 32),

                      // Action buttons
                      _buildActionButtons(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildOverallFeedback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: AppTheme.primary, size: 32),
              const SizedBox(width: 12),
              Text(
                'Overall Assessment',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _scores!.overallFeedback,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerScore(String partnerId, String name, PartnerScore score) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.getPartnerColor(partnerId),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      partnerId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$name\'s Scores',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(score.averageScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(score.averageScore * 100).round()}%',
                    style: TextStyle(
                      color: _getScoreColor(score.averageScore),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Individual scores
            _buildScoreBar('Empathy', score.empathy),
            _buildScoreBar('Listening', score.listening),
            _buildScoreBar('Reception', score.reception),
            _buildScoreBar('Clarity', score.clarity),
            _buildScoreBar('Respect', score.respect),
            _buildScoreBar('Responsiveness', score.responsiveness),
            _buildScoreBar('Open-Mindedness', score.openMindedness),

            const SizedBox(height: 24),

            // Strengths
            if (score.strengths.isNotEmpty) ...[
              Text(
                'Strengths',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.successGreen),
              ),
              const SizedBox(height: 8),
              ...score.strengths.map(
                (strength) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.successGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strength,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Areas for improvement
            if (score.improvements.isNotEmpty) ...[
              Text(
                'Areas for Growth',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              ...score.improvements.map(
                (improvement) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          improvement,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar(String label, double score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '${(score * 100).round()}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementSuggestions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppTheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Suggestions for Growth',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._scores!.improvementSuggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _returnHome,
            icon: const Icon(Icons.home),
            label: const Text('Return to Home'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate to insights dashboard
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/insights',
                (route) => false,
              );
            },
            icon: const Icon(Icons.analytics),
            label: const Text('View Detailed Insights'),
          ),
        ),
      ],
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
