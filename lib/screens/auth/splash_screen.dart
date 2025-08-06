import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../providers/firebase_app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    _scaleController.forward();
    
    // Wait for animations to complete
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      _navigateBasedOnAuthState();
    }
  }

  void _navigateBasedOnAuthState() {
    if (_hasNavigated) return;
    
    final appState = Provider.of<FirebaseAppState>(context, listen: false);
    
    // Wait for auth state to be fully initialized
    if (appState.isLoading) {
      // Check again after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_hasNavigated) {
          _navigateBasedOnAuthState();
        }
      });
      return;
    }
    
    _hasNavigated = true;
    
    // If user is authenticated, go directly to main app
    if (appState.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/');
    } else {
      // If not authenticated, show the start screen
      Navigator.pushReplacementNamed(context, '/start');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      const AppLogo(size: 120, animate: true),
                      
                      SizedBox(height: AppTheme.spacingL),
                      
                      // App Name with gradient
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                        ).createShader(bounds),
                        child: Text(
                          'Mend',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 42.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      SizedBox(height: AppTheme.spacingS),
                      
                      // Subtitle
                      Text(
                        'AI-Powered Relationship Companion',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: 60.h),
                      
                      // Loading indicator
                      SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 2.w,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}