import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../providers/app_state.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import 'scoring_screen.dart';

class PostResolutionScreen extends StatefulWidget {
  const PostResolutionScreen({super.key});

  @override
  State<PostResolutionScreen> createState() => _PostResolutionScreenState();
}

class _PostResolutionScreenState extends State<PostResolutionScreen> {
  final PageController _pageController = PageController();
  final AIService _aiService = AIService();

  int _currentPage = 0;
  String _gratitudeResponseA = '';
  String _gratitudeResponseB = '';
  String _reflectionResponseA = '';
  String _reflectionResponseB = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCelebration();
    });
  }

  void _showCelebration() {
    final celebratoryMessage = _aiService.getCelebratoryMessage();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Heart animation (using simple icon for MVP)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite,
                size: 50,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Congratulations!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              celebratoryMessage,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _nextPage();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeFlow();
    }
  }

  void _completeFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScoringScreen()),
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
            title: const Text('Resolution Complete'),
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.gradientStart,
                  AppTheme.gradientEnd,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentPage + 1) / 4,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.successGreen,
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildGratitudePage(
                      currentPartner?.name ?? 'Partner A',
                      otherPartner?.name ?? 'Partner B',
                    ),
                    _buildReflectionPage(),
                    _buildBondingActivitiesPage(),
                    _buildSummaryPage(),
                  ],
                ),
              ),

              // Navigation
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    child: Text(_currentPage == 3 ? 'View Scores' : 'Continue'),
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

  Widget _buildGratitudePage(String partnerAName, String partnerBName) {
    final gratitudePrompt = _aiService.getGratitudePrompt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.favorite, color: AppTheme.successGreen, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Express Gratitude',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  gratitudePrompt,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Partner A gratitude
          _buildGratitudeSection(
            'A',
            partnerAName,
            _gratitudeResponseA,
            (value) => setState(() => _gratitudeResponseA = value),
          ),

          const SizedBox(height: 24),

          // Partner B gratitude
          _buildGratitudeSection(
            'B',
            partnerBName,
            _gratitudeResponseB,
            (value) => setState(() => _gratitudeResponseB = value),
          ),
        ],
      ),
    );
  }

  Widget _buildGratitudeSection(
    String partnerId,
    String name,
    String value,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
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
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$name\'s Gratitude',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: 'Share what you appreciated about your partner...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildReflectionPage() {
    final reflectionQuestion = _aiService.getReflectionQuestion();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.lightbulb, color: AppTheme.primary, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Shared Reflection',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  reflectionQuestion,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Reflection responses
          TextField(
            decoration: InputDecoration(
              labelText: 'Partner A\'s Reflection',
              hintText: 'Share your thoughts...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.getPartnerColor('A'),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            maxLines: 4,
            onChanged: (value) => setState(() => _reflectionResponseA = value),
          ),

          const SizedBox(height: 24),

          TextField(
            decoration: InputDecoration(
              labelText: 'Partner B\'s Reflection',
              hintText: 'Share your thoughts...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.getPartnerColor('B'),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            maxLines: 4,
            onChanged: (value) => setState(() => _reflectionResponseB = value),
          ),
        ],
      ),
    );
  }

  Widget _buildBondingActivitiesPage() {
    final activities = _aiService.getBondingActivities();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.favorite_border, color: AppTheme.primary, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Strengthen Your Bond',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Here are some activities to help you connect and build on today\'s progress',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Suggested Activities',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 16),

          ...activities.map(
            (activity) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.favorite, color: AppTheme.primary),
                ),
                title: Text(activity),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.successGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Remember: Small, consistent actions strengthen relationships more than grand gestures.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Session Complete!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.successGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ve successfully completed a guided conversation session.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text('What\'s Next?', style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: 16),

          _buildNextStepCard(
            Icons.analytics,
            'View Your Scores',
            'See detailed feedback on your communication skills',
          ),

          _buildNextStepCard(
            Icons.insights,
            'Track Progress',
            'Monitor your relationship growth over time',
          ),

          _buildNextStepCard(
            Icons.chat,
            'Schedule Next Session',
            'Regular conversations lead to stronger connections',
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.celebration, color: AppTheme.primary, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Great job working together!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your commitment to better communication is strengthening your relationship.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepCard(IconData icon, String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
