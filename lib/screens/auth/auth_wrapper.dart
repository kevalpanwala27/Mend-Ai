import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import 'login_screen.dart';
import '../onboarding/welcome_screen.dart';
import '../main/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        print(
          'AuthWrapper: isLoading= [33m${appState.isLoading} [0m, user= [36m${appState.user} [0m, onboarding= [32m${appState.isOnboardingComplete} [0m',
        );
        // Show loading screen while initializing
        if (appState.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is authenticated
        if (appState.user != null) {
          // Check if onboarding is complete
          if (appState.isOnboardingComplete) {
            return const HomeScreen();
          } else {
            return const WelcomeScreen();
          }
        }

        // Default to login screen
        return const LoginScreen();
      },
    );
  }
}
