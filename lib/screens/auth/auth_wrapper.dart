import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../../providers/firebase_app_state.dart';
import '../onboarding/questionnaire_screen.dart';
import '../main/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        developer.log(
          'AuthWrapper: isLoading=\u001b[33m${appState.isLoading}\u001b[0m, user=\u001b[36m${appState.user}\u001b[0m, onboarding=\u001b[32m${appState.isOnboardingComplete}\u001b[0m',
        );
        // Show loading screen while initializing
        if (appState.isLoading) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Container(
              decoration: const BoxDecoration(color: Colors.black),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3.w,
                ),
              ),
            ),
          );
        }
        // User is authenticated
        if (appState.user != null) {
          // Check if email is verified for email/password users
          final isEmailPasswordUser = appState.user!.providerData.isNotEmpty &&
              appState.user!.providerData.first.providerId == 'password';
          
          if (isEmailPasswordUser && !appState.user!.emailVerified) {
            // Email not verified, navigate to verification screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ModalRoute.of(context)?.settings.name != '/verify-email') {
                Navigator.pushReplacementNamed(context, '/verify-email');
              }
            });
            return Scaffold(
              backgroundColor: Colors.black,
              body: Container(
                decoration: const BoxDecoration(color: Colors.black),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3.w,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Checking email verification...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          
          developer.log(
            'AuthWrapper: User verified, onboarding=${appState.isOnboardingComplete}',
          );
          
          // If onboarding is complete, go to HomeScreen
          if (appState.isOnboardingComplete) {
            return const HomeScreen();
          } else {
            // Show QuestionnaireScreen if onboarding is not complete
            return const QuestionnaireScreen();
          }
        }
        // User is not authenticated, navigate to start screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ModalRoute.of(context)?.settings.name != '/start') {
            Navigator.pushReplacementNamed(context, '/start');
          }
        });
        
        return Scaffold(
          backgroundColor: Colors.black,
          body: Container(
            decoration: const BoxDecoration(color: Colors.black),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3.w,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Redirecting...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
