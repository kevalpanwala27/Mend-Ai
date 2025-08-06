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

  // Sign in with email and password
  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      debugPrint('🔐 FirebaseAuthService: Starting sign in for: $email');
      final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      debugPrint('✅ FirebaseAuthService: Sign in successful for user: ${result.user?.uid}');
      return null; // Success
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthService: Firebase auth error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for this email address.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      debugPrint('Unexpected error in sign-in: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Sign up with email and password
  Future<String?> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Send email verification
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
      }
      
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'email-already-in-use':
          return 'An account already exists for this email address.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled.';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      debugPrint('Unexpected error in sign-up: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Send password reset email
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for this email address.';
        case 'invalid-email':
          return 'The email address is not valid.';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      debugPrint('Unexpected error in password reset: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Send email verification
  Future<String?> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return null; // Success
      }
      return 'No user found or email already verified.';
    } on FirebaseAuthException catch (e) {
      return 'Error sending verification email: ${e.message}';
    } catch (e) {
      debugPrint('Unexpected error sending verification email: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Check if email is verified
  Future<void> reloadUser() async {
    await currentUser?.reload();
  }

  // Get email verification status
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

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
