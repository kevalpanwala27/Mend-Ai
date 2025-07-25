import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../models/partner.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../theme/app_theme.dart';
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
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;
  
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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOutQuart,
    ));
    
    // Stagger animations for a more polished feel
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _bounceController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _customGoalController.dispose();
    _customChallengeController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
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
                AppTheme.background,
                Color(0xFFF8F9FA),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
            // Enhanced Progress indicator
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 16.h,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentPage + 1} of 4',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${((_currentPage + 1) / 4 * 100).round()}%',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(3.r),
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
                          borderRadius: BorderRadius.circular(3.r),
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
              padding: EdgeInsets.all(24.w),
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
                    SizedBox(width: 16.w),
                  ],
                  Expanded(
                    flex: _currentPage > 0 ? 1 : 2,
                    child: GradientButton(
                      text: _currentPage == 3 ? 'Start' : 'Next',
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
      padding: EdgeInsets.symmetric(
        horizontal: 24.w,
        vertical: 20.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header with elegant styling and animations
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _bounceAnimation,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(32.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary.withOpacity(0.12),
                        AppTheme.secondary.withOpacity(0.08),
                        AppTheme.accent.withOpacity(0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Elegant icon container
                      Container(
                        width: 80.w,
                        height: 80.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primary.withOpacity(0.2),
                              AppTheme.secondary.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Icon(
                          Icons.favorite_outline_rounded,
                          color: AppTheme.primary,
                          size: 36.sp,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        "Let's Begin Your Mend Journey",
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'To personalize your experience, tell us a bit about yourself.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 40.h),

          // Name field with modern styling and animations
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppTheme.secondary.withOpacity(0.04),
                      blurRadius: 40,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Name',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: _name.isNotEmpty 
                              ? AppTheme.primary.withOpacity(0.3)
                              : AppTheme.borderColor,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _nameController,
                        onChanged: (value) => setState(() => _name = value),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your first name',
                          hintStyle: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textTertiary,
                          ),
                          prefixIcon: Container(
                            padding: EdgeInsets.all(12.w),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: _name.isNotEmpty 
                                  ? AppTheme.primary 
                                  : AppTheme.textTertiary,
                              size: 20.sp,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 20.h,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 32.h),

          // Gender selection with modern chips and animations
          SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppTheme.secondary.withOpacity(0.04),
                      blurRadius: 40,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 12.h,
                      children: ['Male', 'Female', 'Non-Binary', 'Prefer not to say']
                          .map((gender) {
                        final isSelected = _gender == gender;
                        
                        return GestureDetector(
                          onTap: () => setState(() => _gender = gender),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 20.w,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.primary.withOpacity(0.8),
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : AppTheme.background,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.borderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              gender,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 60.h),
        ],
      ),
    );
  }

  Widget _buildGoalsPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you want to improve?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 8.h),
          Text(
            'Select all that apply to your relationship goals',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 32.h),

          // Goal options
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
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

          SizedBox(height: 24.h),

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
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What challenges are you facing?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 8.h),
          Text(
            'Understanding your challenges helps us provide better guidance',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 32.h),

          // Challenge options
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
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

          SizedBox(height: 24.h),

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
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready to get started!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 8.h),
          Text(
            "Here's a summary of your responses",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 32.h),

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

          SizedBox(height: 24.h),

          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: 8.h),
                Text(
                  "Mend works best with your partner! After completing setup, you'll get an invite code to share.",
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
      margin: EdgeInsets.only(bottom: 16.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8.h),
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