import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import 'login_screen.dart';
import '../onboarding/questionnaire_screen.dart';
import '../main/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        print(
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
          // If onboarding is complete, go to HomeScreen
          if (appState.isOnboardingComplete) {
            return const HomeScreen();
          } else {
            // Show QuestionnaireScreen if onboarding is not complete
            return const QuestionnaireScreen();
          }
        }
        // Default to login screen
        return const LoginScreen();
      },
    );
  }
}
