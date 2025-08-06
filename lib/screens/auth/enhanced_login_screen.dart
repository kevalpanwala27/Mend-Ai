import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/gradient_button.dart';

class EnhancedLoginScreen extends StatefulWidget {
  const EnhancedLoginScreen({super.key});

  @override
  State<EnhancedLoginScreen> createState() => _EnhancedLoginScreenState();
}

class _EnhancedLoginScreenState extends State<EnhancedLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isSignUp = false;
  late AnimationController _bounceController;
  late AnimationController _switchController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _switchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bounceController.dispose();
    _switchController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final error = await context.read<FirebaseAppState>().signInWithGoogle();

      if (error != null && mounted) {
        _showErrorSnackBar('Failed to sign in: $error');
      }
    } catch (e, stack) {
      debugPrint('Unexpected error in sign-in: $e\n$stack');
      if (mounted) {
        _showErrorSnackBar('Unexpected error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    debugPrint('🔐 Sign-in button pressed');
    
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Form validation failed');
      return;
    }

    debugPrint('✅ Form validation passed, proceeding with ${_isSignUp ? 'sign up' : 'sign in'}');
    setState(() => _isLoading = true);

    try {
      final appState = context.read<FirebaseAppState>();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      debugPrint('📧 Email: $email');
      debugPrint('🔒 Password length: ${password.length}');
      
      final error = _isSignUp
          ? await appState.signUpWithEmailPassword(email, password)
          : await appState.signInWithEmailPassword(email, password);

      debugPrint('🔄 Authentication result: ${error == null ? 'SUCCESS' : 'ERROR: $error'}');

      if (mounted) {
        if (error != null) {
          _showErrorSnackBar(error);
        } else if (_isSignUp) {
          _showSuccessSnackBar('Account created! Please check your email for verification.');
        } else {
          // Sign in was successful - navigate to root and let AuthWrapper handle routing
          debugPrint('✅ Sign in successful, navigating to AuthWrapper');
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('💥 Unexpected error in email auth: $e\n$stack');
      if (mounted) {
        _showErrorSnackBar('Unexpected error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your email address first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final error = await context.read<FirebaseAppState>().resetPassword(
        _emailController.text.trim(),
      );

      if (error != null && mounted) {
        _showErrorSnackBar(error);
      } else if (mounted) {
        _showSuccessSnackBar('Password reset email sent! Check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error sending reset email: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  void _toggleAuthMode() {
    setState(() => _isSignUp = !_isSignUp);
    _switchController.forward().then((_) {
      _switchController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingText: _isSignUp ? 'Creating account...' : 'Signing you in...',
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(color: Colors.black),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 20.h),

                    // App Logo with animation
                    const AppLogo(size: 100, animate: true),

                    SizedBox(height: AppTheme.spacingL),

                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                      ).createShader(bounds),
                      child: Text(
                        _isSignUp ? 'Create Account' : 'Welcome Back',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: AppTheme.spacingS),

                    Text(
                      _isSignUp 
                          ? 'Join thousands of couples improving their relationships'
                          : 'Continue your relationship journey',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 40.h),

                    // Email/Password Form
                    AnimatedCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email Field
                              _buildEmailField(),
                              
                              SizedBox(height: AppTheme.spacingM),
                              
                              // Password Field
                              _buildPasswordField(),
                              
                              if (!_isSignUp) ...[
                                SizedBox(height: AppTheme.spacingS),
                                // Forgot Password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _resetPassword,
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              
                              SizedBox(height: AppTheme.spacingL),
                              
                              // Submit Button
                              GradientButton(
                                text: _isSignUp ? 'Create Account' : 'Sign In',
                                onPressed: _signInWithEmail,
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: AppTheme.spacingL),

                    // Or divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppTheme.borderColor)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppTheme.borderColor)),
                      ],
                    ),

                    SizedBox(height: AppTheme.spacingL),

                    // Google Sign In button
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _signInWithGoogle,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(color: AppTheme.borderColor, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/google_logo.svg',
                                width: 20,
                                height: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: AppTheme.spacingL),

                    // Switch between Sign In/Sign Up
                    TextButton(
                      onPressed: _toggleAuthMode,
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: _isSignUp 
                                  ? 'Already have an account? '
                                  : 'Don\'t have an account? ',
                            ),
                            TextSpan(
                              text: _isSignUp ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: AppTheme.spacingL),

                    // Privacy notice
                    Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email address',
        prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textTertiary),
        filled: true,
        fillColor: AppTheme.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.interruptionColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.interruptionColor, width: 2),
        ),
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        hintStyle: TextStyle(color: AppTheme.textTertiary),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Email is required';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: _isSignUp ? 'Create a strong password' : 'Enter your password',
        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textTertiary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.textTertiary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: AppTheme.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.interruptionColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          borderSide: BorderSide(color: AppTheme.interruptionColor, width: 2),
        ),
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        hintStyle: TextStyle(color: AppTheme.textTertiary),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password is required';
        }
        if (_isSignUp && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }
}