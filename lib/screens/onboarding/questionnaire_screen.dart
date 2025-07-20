import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../models/partner.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../theme/app_theme.dart';
import 'invite_code_screen.dart';
import '../main/home_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customGoalController = TextEditingController();
  final TextEditingController _customChallengeController = TextEditingController();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _currentPage = 0;
  bool _isLoading = false;

  // Form data
  String _name = '';
  String _gender = '';
  final Set<String> _relationshipGoals = {};
  final Set<String> _currentChallenges = {};
  String _customGoal = '';
  String _customChallenge = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _customGoalController.dispose();
    _customChallengeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

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
        SnackBar(
          content: const Text('Please fill in all required fields'),
          backgroundColor: AppTheme.interruptionColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing onboarding: $e'),
            backgroundColor: AppTheme.interruptionColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingText: 'Setting up your relationship profile...',
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Getting to Know You'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _currentPage > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: _previousPage,
                )
              : null,
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
            // Enhanced Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingM,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentPage + 1} of 4',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${((_currentPage + 1) / 4 * 100).round()}%',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_currentPage + 1) / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.gradientStart,
                              AppTheme.gradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _fadeController.reset();
                    _fadeController.forward();
                  },
                  children: [
                    _buildBasicInfoPage(),
                    _buildGoalsPage(),
                    _buildChallengesPage(),
                    _buildSummaryPage(),
                  ],
                ),
              ),
            ),

            // Enhanced Navigation buttons
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (_currentPage > 0) ...[
                    Expanded(
                      child: GradientButton(
                        text: 'Previous',
                        icon: Icons.arrow_back_ios_rounded,
                        isSecondary: true,
                        onPressed: _previousPage,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                  ],
                  Expanded(
                    flex: _currentPage > 0 ? 1 : 2,
                    child: GradientButton(
                      text: _currentPage == 3 ? 'Complete Setup' : 'Next',
                      icon: _currentPage == 3 
                          ? Icons.check_rounded 
                          : Icons.arrow_forward_ios_rounded,
                      onPressed: _nextPage,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          AnimatedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppTheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'Let\'s start with the basics',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'This helps us personalize your experience and create better communication guidance',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Name field
          AnimatedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  labelText: 'Your Name',
                  hintText: 'Enter your first name',
                  controller: _nameController,
                  prefixIcon: const Icon(Icons.person_rounded),
                  onChanged: (value) => setState(() => _name = value),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Gender selection
          AnimatedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gender',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Wrap(
                  spacing: AppTheme.spacingM,
                  runSpacing: AppTheme.spacingS,
                  children: ['Male', 'Female', 'Other'].map((gender) {
                    final isSelected = _gender == gender;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ChoiceChip(
                        label: Text(
                          gender,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.cardBackground,
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : AppTheme.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                        onSelected: (selected) {
                          setState(() => _gender = selected ? gender : '');
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
