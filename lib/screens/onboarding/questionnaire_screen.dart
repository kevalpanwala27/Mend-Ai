import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../models/partner.dart';
import 'invite_code_screen.dart';
import '../main/home_screen.dart'; // Corrected import for HomeScreen

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form data
  String _name = '';
  String _gender = '';
  final Set<String> _relationshipGoals = {};
  final Set<String> _currentChallenges = {};
  String _customGoal = '';
  String _customChallenge = '';

  final List<String> _goalOptions = [
    'Communication',
    'Conflict resolution',
    'Intimacy',
    'Trust',
    'Shared decision-making',
  ];

  final List<String> _challengeOptions = [
    'Frequent arguments',
    'Feeling unheard or misunderstood',
    'Lack of quality time together',
    'Financial stress',
    'Differences in parenting styles',
    'Loss of intimacy',
    'External pressures (work, family)',
  ];

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    if (_name.isEmpty || _gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final partner = Partner(
      id: 'A', // First partner is always A
      name: _name,
      gender: _gender,
      relationshipGoals: _relationshipGoals.toList(),
      currentChallenges: _currentChallenges.toList(),
      customGoal: _customGoal.isNotEmpty ? _customGoal : null,
      customChallenge: _customChallenge.isNotEmpty ? _customChallenge : null,
    );

    await context.read<FirebaseAppState>().completeOnboarding(partner);
    final appState = context.read<FirebaseAppState>();
    final relationshipData = appState.relationshipData;
    if (mounted) {
      if (relationshipData != null && relationshipData['partnerB'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const InviteCodeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting to Know You'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              )
            : null,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentPage + 1) / 4,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
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
                _buildBasicInfoPage(),
                _buildGoalsPage(),
                _buildChallengesPage(),
                _buildSummaryPage(),
              ],
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    child: Text(_currentPage == 3 ? 'Complete' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let\'s start with the basics',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us personalize your experience',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),

          // Name field
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Your Name',
              hintText: 'Enter your first name',
            ),
            onChanged: (value) => setState(() => _name = value),
          ),

          const SizedBox(height: 24),

          // Gender selection
          Text('Gender', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: ['Male', 'Female', 'Other'].map((gender) {
              return ChoiceChip(
                label: Text(gender),
                selected: _gender == gender,
                onSelected: (selected) {
                  setState(() => _gender = selected ? gender : '');
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you want to improve?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply to your relationship goals',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),

          // Goal options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goalOptions.map((goal) {
              return FilterChip(
                label: Text(goal),
                selected: _relationshipGoals.contains(goal),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _relationshipGoals.add(goal);
                    } else {
                      _relationshipGoals.remove(goal);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Custom goal
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Other (Optional)',
              hintText: 'Describe any other goals...',
            ),
            maxLines: 2,
            onChanged: (value) => setState(() => _customGoal = value),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What challenges are you facing?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Understanding your challenges helps us provide better guidance',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),

          // Challenge options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _challengeOptions.map((challenge) {
              return FilterChip(
                label: Text(challenge),
                selected: _currentChallenges.contains(challenge),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _currentChallenges.add(challenge);
                    } else {
                      _currentChallenges.remove(challenge);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Custom challenge
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Other (Optional)',
              hintText: 'Describe any other challenges...',
            ),
            maxLines: 2,
            onChanged: (value) => setState(() => _customChallenge = value),
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
          Text(
            'Ready to get started!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s a summary of your responses',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),

          // Summary cards
          _buildSummaryCard('Name', _name),
          _buildSummaryCard('Gender', _gender),
          _buildSummaryCard(
            'Relationship Goals',
            _relationshipGoals.join(', ') +
                (_customGoal.isNotEmpty ? ', $_customGoal' : ''),
          ),
          _buildSummaryCard(
            'Current Challenges',
            _currentChallenges.join(', ') +
                (_customChallenge.isNotEmpty ? ', $_customChallenge' : ''),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Mend works best with your partner! After completing setup, you\'ll get an invite code to share.',
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

  Widget _buildSummaryCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              content.isEmpty ? 'Not specified' : content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
