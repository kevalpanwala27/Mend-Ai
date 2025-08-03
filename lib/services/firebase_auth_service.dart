import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleSignInResult {
  final UserCredential? userCredential;
  final String? errorMessage;

  GoogleSignInResult({this.userCredential, this.errorMessage});
}

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final client = _googleSignIn.authorizationClient;
      final authz = await client.authorizeScopes([
        'email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ]);
      if (authz.accessToken.isEmpty) {
        return GoogleSignInResult(
          errorMessage: 'Sign-in cancelled or not authorized by user.',
        );
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: authz.accessToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return GoogleSignInResult(userCredential: userCredential);
    } catch (e, stack) {
      debugPrint('Error signing in with Google: $e\n$stack');
      return GoogleSignInResult(errorMessage: e.toString());
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  // Get user profile data
  Map<String, dynamic>? get userProfile {
    final user = currentUser;
    if (user == null) return null;

    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'createdAt': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
    };
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
}
