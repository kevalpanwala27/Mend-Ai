import 'package:flutter/material.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_button.dart';
import '../../theme/app_theme.dart';
import 'questionnaire_screen.dart';
import 'join_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Animated App Logo
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const AppLogo(
                    size: 140,
                    animate: true,
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXL),

                // App Name with animation
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AppTheme.gradientStart,
                          AppTheme.gradientEnd,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'Mend',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingM),

                // Tagline
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Your AI-powered relationship companion',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingM),

                // Description
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                      ),
                      child: Text(
                        'Guide natural communication, resolve conflicts, and foster emotional closeness through AI-powered conversation',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textTertiary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Feature highlights
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFeatureItem(
                          Icons.record_voice_over_rounded,
                          'Voice Chat',
                        ),
                        _buildFeatureItem(
                          Icons.psychology_rounded,
                          'AI Guidance',
                        ),
                        _buildFeatureItem(
                          Icons.analytics_rounded,
                          'Progress Tracking',
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Buttons
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Get Started Button (Partner A)
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            text: 'Create New Relationship',
                            icon: Icons.add_rounded,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const QuestionnaireScreen(),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: AppTheme.spacingM),

                        // Join Partner Button (Partner B)
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            text: 'Join with Invite Code',
                            icon: Icons.person_add_rounded,
                            isSecondary: true,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const JoinScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingXL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Icon(
            icon,
            color: AppTheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
