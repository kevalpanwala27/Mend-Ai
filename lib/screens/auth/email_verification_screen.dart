import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/loading_overlay.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _isResending = false;
  bool _isCheckingPeriodically = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Start checking after a brief delay to avoid immediate UI updates
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkVerificationPeriodically();
      }
    });
  }

  void _checkVerificationPeriodically() async {
    final appState = context.read<FirebaseAppState>();
    
    while (mounted && _isCheckingPeriodically && !_isNavigating) {
      try {
        // Only reload if not currently loading something else
        if (!_isLoading && !_isResending && !_isNavigating) {
          await appState.reloadUser();
          
          if (mounted && appState.isEmailVerified && !_isNavigating) {
            // Email verified, stop checking and navigate
            _isNavigating = true;
            _isCheckingPeriodically = false;
            
            // Small delay to show success state
            await Future.delayed(const Duration(milliseconds: 500));
            
            if (mounted && !_isNavigating) {
              // Navigate to root and let AuthWrapper handle the routing
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            }
            return;
          }
        }
        
        // Wait 5 seconds between checks (increased from 3)
        await Future.delayed(const Duration(seconds: 5));
        
      } catch (e) {
        // If error occurs, wait longer before next attempt
        await Future.delayed(const Duration(seconds: 10));
      }
    }
  }

  @override
  void dispose() {
    _isCheckingPeriodically = false;
    super.dispose();
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);

    try {
      final error = await context.read<FirebaseAppState>().sendEmailVerification();
      
      if (error != null && mounted) {
        _showErrorSnackBar(error);
      } else if (mounted) {
        _showSuccessSnackBar('Verification email sent! Check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error sending verification email: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkVerification() async {
    if (_isNavigating) return;
    
    setState(() => _isLoading = true);

    try {
      final appState = context.read<FirebaseAppState>();
      await appState.reloadUser();
      
      if (mounted && !_isNavigating) {
        if (appState.isEmailVerified) {
          // Stop periodic checking and set navigation flag
          _isNavigating = true;
          _isCheckingPeriodically = false;
          
          _showSuccessSnackBar('Email verified successfully!');
          // Navigate to home after a short delay
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            // Navigate to root and let AuthWrapper handle the routing
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          }
        } else {
          _showErrorSnackBar('Email not yet verified. Please check your inbox.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error checking verification: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await context.read<FirebaseAppState>().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth',
        (route) => false,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.interruptionColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use select instead of watch to prevent unnecessary rebuilds
    final user = context.select<FirebaseAppState, User?>((state) => state.user);
    
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingText: 'Checking verification...',
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(color: Colors.black),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 60.h),

                          // App Logo
                          const AppLogo(size: 100, animate: true),

                          SizedBox(height: AppTheme.spacingXL),

                          // Title
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                            ).createShader(bounds),
                            child: Text(
                              'Verify Your Email',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          SizedBox(height: AppTheme.spacingM),

                          // Email address
                          Text(
                            user?.email ?? 'your email',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: 40.h),

                          // Main card with instructions
                          AnimatedCard(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingL),
                              child: Column(
                                children: [
                                  // Email icon
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                                    ),
                                    child: Icon(
                                      Icons.mark_email_unread_rounded,
                                      size: 40,
                                      color: AppTheme.primary,
                                    ),
                                  ),

                                  SizedBox(height: AppTheme.spacingL),

                                  Text(
                                    'Check Your Inbox',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  SizedBox(height: AppTheme.spacingS),

                                  Text(
                                    'We\'ve sent a verification email to your address. Please click the verification link in the email to continue.',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.textSecondary,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  SizedBox(height: AppTheme.spacingL),

                                  // Instructions
                                  _buildInstructionItem('1', 'Check your email inbox'),
                                  _buildInstructionItem('2', 'Click the verification link'),
                                  _buildInstructionItem('3', 'Return to this app'),

                                  SizedBox(height: AppTheme.spacingL),

                                  // Note about spam
                                  Container(
                                    padding: const EdgeInsets.all(AppTheme.spacingM),
                                    decoration: BoxDecoration(
                                      color: AppTheme.aiActive.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                      border: Border.all(
                                        color: AppTheme.aiActive.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: AppTheme.aiActive,
                                          size: 20,
                                        ),
                                        SizedBox(width: AppTheme.spacingS),
                                        Expanded(
                                          child: Text(
                                            'Don\'t see the email? Check your spam folder',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 40.h),
                        ],
                      ),
                    ),
                  ),

                  // Action buttons
                  Column(
                    children: [
                      // Check verification button
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          text: 'I\'ve Verified My Email',
                          onPressed: _checkVerification,
                          isLoading: _isLoading,
                        ),
                      ),

                      SizedBox(height: AppTheme.spacingM),

                      // Resend button
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          text: _isResending ? 'Sending...' : 'Resend Email',
                          onPressed: _isResending ? null : _resendVerification,
                          isSecondary: true,
                        ),
                      ),

                      SizedBox(height: AppTheme.spacingL),

                      // Sign out option
                      TextButton(
                        onPressed: _signOut,
                        child: Text(
                          'Sign out and use different email',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}