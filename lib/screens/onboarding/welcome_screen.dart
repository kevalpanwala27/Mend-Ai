import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/gradient_button.dart';
import '../../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Non-Binary',
    'Prefer not to say'
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate() && _selectedGender != null) {
      setState(() {
        _isLoading = true;
      });
      
      // Simulate API call or navigation delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          // TODO: Navigate to next screen (relationship goals)
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome information saved! Ready for next screen...'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      });
    } else if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender to continue'),
          backgroundColor: AppTheme.interruptionColor,
        ),
      );
    }
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16.sp,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
          ),
          child: Column(
            children: _genderOptions.map((gender) {
              final isSelected = _selectedGender == gender;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGender = gender;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(vertical: 2.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: isSelected
                        ? Border.all(
                            color: AppTheme.primary,
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected 
                                ? AppTheme.primary 
                                : AppTheme.borderColor,
                            width: 2,
                          ),
                          color: isSelected 
                              ? AppTheme.primary 
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 12.sp,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          gender,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isSelected 
                                ? AppTheme.primary 
                                : AppTheme.textSecondary,
                            fontWeight: isSelected 
                                ? FontWeight.w600 
                                : FontWeight.w400,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 60.h),
                  
                  // Header Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: Column(
                        children: [
                          // Logo placeholder - using heart icon for now
                          Container(
                            width: 80.w,
                            height: 80.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.gradientStart,
                                  AppTheme.gradientEnd,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 40.sp,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          
                          // Headline
                          Text(
                            "Let's Begin Your\nMend Journey",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          
                          // Subtext
                          Text(
                            "To personalize your experience,\ntell us a bit about yourself.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16.sp,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 48.h),
                  
                  // Form Section
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name Input
                          Text(
                            'Name',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextFormField(
                            controller: _nameController,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textPrimary,
                              fontSize: 16.sp,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your name',
                              hintStyle: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 16.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: AppTheme.textTertiary,
                                size: 20.sp,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 16.h,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              if (value.trim().length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                          
                          SizedBox(height: 32.h),
                          
                          // Gender Selection
                          _buildGenderSelector(),
                          
                          SizedBox(height: 48.h),
                          
                          // Next Button
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              text: 'Next',
                              onPressed: _handleNext,
                              isLoading: _isLoading,
                              height: 56.h,
                              fontSize: 18.sp,
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
        ),
      ),
    );
  }
}
