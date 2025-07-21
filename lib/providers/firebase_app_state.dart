import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/partner.dart';
import '../models/communication_session.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_invite_service.dart';
import '../services/firestore_relationship_service.dart';
import '../services/firestore_sessions_service.dart';

class InviteJoinResult {
  final bool isSuccess;
  final String? errorMessage;

  const InviteJoinResult._({required this.isSuccess, this.errorMessage});

  factory InviteJoinResult.success() {
    return const InviteJoinResult._(isSuccess: true);
  }

  factory InviteJoinResult.failure(String message) {
    return InviteJoinResult._(isSuccess: false, errorMessage: message);
  }
}

class FirebaseAppState extends ChangeNotifier {
  // Services
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreInviteService _inviteService = FirestoreInviteService();
  final FirestoreRelationshipService _relationshipService =
      FirestoreRelationshipService();
  final FirestoreSessionsService _sessionsService = FirestoreSessionsService();

  // State
  User? _user;
  Map<String, dynamic>? _relationshipData;
  List<CommunicationSession> _sessions = [];
  CommunicationSession? _currentSession;
  String? _currentSessionId;
  bool _isOnboardingComplete = false;
  String? _currentUserId;
  bool _isLoading = true;

  // Getters
  User? get user => _user;
  Map<String, dynamic>? get relationshipData => _relationshipData;
  List<CommunicationSession> get sessions => _sessions;
  CommunicationSession? get currentSession => _currentSession;
  bool get isOnboardingComplete => _isOnboardingComplete;
  String? get currentUserId => _currentUserId;
  bool get hasPartner => _relationshipData?['partnerB'] != null;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  // Initialize the app state
  Future<void> initialize() async {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) async {
      print('Auth state changed: $user');
      _user = user;
      if (user != null) {
        await _loadUserData();
      } else {
        _clearUserData();
      }
      _isLoading = false;
      notifyListeners();
    });

    // Get initial auth state
    _user = _authService.currentUser;
    if (_user != null) {
      await _loadUserData();
    }
    _isLoading = false;
    notifyListeners();
  }

  // Load user data from Firestore
  Future<void> _loadUserData() async {
    print('Loading user data...');
    try {
      // Load relationship data
      _relationshipData = await _relationshipService.getUserRelationship();
      print('User data loaded:  [32m [1m [4m [7m$_relationshipData [0m');
      if (_relationshipData != null) {
        _isOnboardingComplete = true;
        // Determine current user ID based on relationship data
        if (_relationshipData!['createdBy'] == _user!.uid) {
          _currentUserId = 'A';
        } else {
          _currentUserId = 'B';
        }
        // Load sessions
        _sessions = await _sessionsService.getRelationshipSessions(
          _relationshipData!['id'],
        );
        // Load active session
        _currentSession = await _sessionsService.getActiveSession(
          _relationshipData!['id'],
        );
      }
      print(
        'Finished loading user data. Onboarding complete: $_isOnboardingComplete',
      );
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // Clear user data
  void _clearUserData() {
    _relationshipData = null;
    _sessions = [];
    _currentSession = null;
    _currentSessionId = null;
    _isOnboardingComplete = false;
    _currentUserId = null;
  }

  // Sign in with Google
  Future<String?> signInWithGoogle() async {
    final result = await _authService.signInWithGoogle();
    print(
      'Current Firebase user after sign-in: ${FirebaseAuth.instance.currentUser}',
    );
    if (result.userCredential != null) {
      return null; // Success, no error
    } else {
      return result.errorMessage ?? 'Unknown error occurred during sign-in.';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Complete onboarding for Partner A
  Future<void> completeOnboarding(Partner partner) async {
    try {
      if (_user == null) {
        throw Exception('User not authenticated');
      }

      _currentUserId = partner.id;

      if (partner.id == 'A') {
        // Create relationship (no invite code)
        final relationshipId = await _relationshipService.createRelationship(
          partner,
          '', // Pass empty string for invite code
        );

        // Load the created relationship
        _relationshipData = await _relationshipService.getRelationshipById(
          relationshipId,
        );
        _isOnboardingComplete = true;

        notifyListeners();
      } else {
        throw Exception('Partner B should use joinWithInviteCode method');
      }
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      rethrow;
    }
  }

  // Join with invite code for Partner B
  Future<InviteJoinResult> joinWithInviteCode(
    String code,
    Partner partner,
  ) async {
    try {
      if (_user == null) {
        return InviteJoinResult.failure('User not authenticated');
      }

      _currentUserId = partner.id;

      // Validate the invite code
      final result = await _inviteService.validateAndUseInvite(code, partner);

      if (result.isValid && result.partner != null) {
        // Find the relationship by invite code
        final relationshipData = await _relationshipService
            .findRelationshipByInviteCode(code);

        if (relationshipData != null) {
          // Join the relationship
          await _relationshipService.joinRelationship(
            relationshipData['id'],
            partner,
          );

          // Load the updated relationship
          _relationshipData = await _relationshipService.getRelationshipById(
            relationshipData['id'],
          );
          _isOnboardingComplete = true;

          notifyListeners();
          return InviteJoinResult.success();
        } else {
          return InviteJoinResult.failure('Relationship not found');
        }
      } else {
        return InviteJoinResult.failure(
          result.errorMessage ?? 'Invalid invite code',
        );
      }
    } catch (e) {
      debugPrint('Error joining with invite code: $e');
      return InviteJoinResult.failure(
        'An error occurred while joining. Please try again.',
      );
    }
  }

  // Start a communication session
  Future<void> startCommunicationSession({String? sessionCode}) async {
    try {
      if (_relationshipData == null || !hasPartner || _user == null) return;

      final session = CommunicationSession(
        id: sessionCode ?? DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        messages: [],
        participantStatus: {
          'A': true,
          'B': true,
        },
      );

      if (sessionCode != null) {
        // Use the existing session document from waiting room
        _currentSessionId = sessionCode;
        await _sessionsService.updateSession(sessionCode, session);
      } else {
        // Create a new session
        _currentSessionId = await _sessionsService.createSession(
          _relationshipData!['id'],
          session,
        );
      }
      
      _currentSession = session;

      notifyListeners();
    } catch (e) {
      debugPrint('Error starting communication session: $e');
    }
  }

  // Add a message to the current session
  Future<void> addMessage(
    String speakerId,
    String content,
    MessageType type, {
    bool wasInterrupted = false,
  }) async {
    try {
      if (_currentSession == null || _currentSessionId == null) return;

      final message = Message(
        speakerId: speakerId,
        content: content,
        timestamp: DateTime.now(),
        type: type,
        wasInterrupted: wasInterrupted,
      );

      _currentSession!.messages.add(message);
      await _sessionsService.addMessage(_currentSessionId!, message);

      notifyListeners();
    } catch (e) {
      debugPrint('Error adding message: $e');
    }
  }

  // Mark current user as left from session
  Future<void> leaveCurrentSession() async {
    try {
      if (_currentSession == null || _currentSessionId == null || _currentUserId == null) {
        debugPrint('Cannot leave session - missing session info: session=$_currentSession, sessionId=$_currentSessionId, userId=$_currentUserId');
        return;
      }

      debugPrint('Leaving session: sessionId=$_currentSessionId, userId=$_currentUserId');
      await _sessionsService.markParticipantLeft(_currentSessionId!, _currentUserId!);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving communication session: $e');
    }
  }

  // End the current communication session
  Future<void> endCommunicationSession({
    CommunicationScores? scores,
    String? reflection,
    List<String>? suggestedActivities,
  }) async {
    try {
      if (_currentSession == null || _currentSessionId == null) return;

      // End the session in Firestore
      await _sessionsService.endSession(
        _currentSessionId!,
        scores: scores,
        reflection: reflection,
        suggestedActivities: suggestedActivities,
      );

      // Update local state
      final completedSession = CommunicationSession(
        id: _currentSession!.id,
        startTime: _currentSession!.startTime,
        endTime: DateTime.now(),
        messages: _currentSession!.messages,
        scores: scores,
        reflection: reflection,
        suggestedActivities: suggestedActivities ?? [],
        participantStatus: _currentSession!.participantStatus,
      );

      _sessions.insert(0, completedSession);
      _currentSession = null;
      _currentSessionId = null;

      // Reload sessions to refresh insights data
      await _reloadSessions();

      notifyListeners();
    } catch (e) {
      debugPrint('Error ending communication session: $e');
    }
  }

  // Reload sessions from Firestore
  Future<void> _reloadSessions() async {
    if (_relationshipData != null) {
      try {
        _sessions = await _sessionsService.getRelationshipSessions(
          _relationshipData!['id'],
        );
      } catch (e) {
        debugPrint('Error reloading sessions: $e');
      }
    }
  }

  // Get current partner
  Partner? getCurrentPartner() {
    if (_relationshipData == null || _currentUserId == null) return null;

    if (_currentUserId == 'A') {
      return _relationshipData!['partnerA'] != null
          ? Partner.fromJson(_relationshipData!['partnerA'])
          : null;
    } else if (_currentUserId == 'B') {
      return _relationshipData!['partnerB'] != null
          ? Partner.fromJson(_relationshipData!['partnerB'])
          : null;
    }
    return null;
  }

  // Get other partner
  Partner? getOtherPartner() {
    if (_relationshipData == null || _currentUserId == null) return null;

    if (_currentUserId == 'A') {
      return _relationshipData!['partnerB'] != null
          ? Partner.fromJson(_relationshipData!['partnerB'])
          : null;
    } else if (_currentUserId == 'B') {
      return _relationshipData!['partnerA'] != null
          ? Partner.fromJson(_relationshipData!['partnerA'])
          : null;
    }
    return null;
  }

  // Get recent sessions
  List<CommunicationSession> getRecentSessions({int limit = 10}) {
    final completedSessions = _sessions.where((s) => s.isCompleted).toList();
    completedSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return completedSessions.take(limit).toList();
  }

  // Get average score for a partner
  double getAverageScore(String partnerId) {
    final recentSessions = getRecentSessions();
    if (recentSessions.isEmpty) return 0.0;

    final scoresWithData = recentSessions
        .where((s) => s.scores?.partnerScores[partnerId] != null)
        .map((s) => s.scores!.partnerScores[partnerId]!.averageScore)
        .toList();

    if (scoresWithData.isEmpty) return 0.0;

    return scoresWithData.reduce((a, b) => a + b) / scoresWithData.length;
  }

  // Clear all data (for testing or user deletion)
  Future<void> clearAllData() async {
    try {
      // Delete relationship if user created it
      if (_relationshipData != null &&
          _relationshipData!['createdBy'] == _user?.uid) {
        await _relationshipService.deleteRelationship(_relationshipData!['id']);
      }

      // Sign out
      await signOut();

      // Clear local state
      _clearUserData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  // Get session statistics
  Future<Map<String, dynamic>> getSessionStatistics() async {
    try {
      if (_relationshipData == null) return {};
      return await _sessionsService.getSessionStatistics(
        _relationshipData!['id'],
      );
    } catch (e) {
      debugPrint('Error getting session statistics: $e');
      return {};
    }
  }

  // Listen to relationship updates
  Stream<Map<String, dynamic>?> getRelationshipStream() {
    if (_relationshipData == null) return Stream.value(null);
    return _relationshipService.getRelationshipStream(_relationshipData!['id']);
  }

  // Listen to session updates
  Stream<List<CommunicationSession>> getSessionsStream() {
    if (_relationshipData == null) return Stream.value([]);
    return _sessionsService.getRelationshipSessionsStream(
      _relationshipData!['id'],
    );
  }

  // Listen to active session updates
  Stream<CommunicationSession?> getActiveSessionStream() {
    if (_relationshipData == null) return Stream.value(null);
    return _sessionsService.getActiveSessionStream(_relationshipData!['id']);
  }
}
