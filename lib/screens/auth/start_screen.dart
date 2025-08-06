import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/gradient_button.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateToAuth() {
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(color: Colors.black),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 40.h),

                      // App Logo
                      const AppLogo(size: 100, animate: true),

                      SizedBox(height: AppTheme.spacingXL),

                      // Welcome Text
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                        ).createShader(bounds),
                        child: Text(
                          'Welcome to Mend',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: AppTheme.spacingM),

                      Text(
                        'Transform your relationship with AI-guided conversations',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 50.h),

                      // Feature Cards
                      _buildFeatureCard(
                        Icons.psychology_rounded,
                        'AI-Powered Guidance',
                        'Get real-time insights and suggestions during your conversations',
                        AppTheme.aiActive,
                      ),

                      SizedBox(height: AppTheme.spacingM),

                      _buildFeatureCard(
                        Icons.record_voice_over_rounded,
                        'Voice Communication',
                        'Practice difficult conversations in a safe, guided environment',
                        AppTheme.partnerBColor,
                      ),

                      SizedBox(height: AppTheme.spacingM),

                      _buildFeatureCard(
                        Icons.analytics_rounded,
                        'Progress Tracking',
                        'Monitor your communication growth and relationship health',
                        AppTheme.partnerAColor,
                      ),

                      SizedBox(height: 50.h),

                      // Benefits section
                      AnimatedCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Column(
                            children: [
                              Text(
                                'Why couples choose Mend',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: AppTheme.spacingM),
                              _buildBenefitItem('✨', 'Improve communication skills'),
                              _buildBenefitItem('🎯', 'Resolve conflicts peacefully'),
                              _buildBenefitItem('📈', 'Strengthen your bond'),
                              _buildBenefitItem('🛡️', 'Private and secure'),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 50.h),

                      // Get Started Button
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          text: 'Get Started',
                          onPressed: _navigateToAuth,
                        ),
                      ),

                      SizedBox(height: AppTheme.spacingL),

                      // Privacy notice
                      Text(
                        'Your privacy is our priority. All conversations are encrypted and secure.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: AppTheme.spacingXL),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String description, Color color) {
    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingXS),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}