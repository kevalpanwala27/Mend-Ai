import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/partner.dart';
import '../models/communication_session.dart';
import '../services/invite_service.dart';

class InviteJoinResult {
  final bool isSuccess;
  final String? errorMessage;

  const InviteJoinResult._({
    required this.isSuccess,
    this.errorMessage,
  });

  factory InviteJoinResult.success() {
    return const InviteJoinResult._(isSuccess: true);
  }

  factory InviteJoinResult.failure(String message) {
    return InviteJoinResult._(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

class AppState extends ChangeNotifier {
  RelationshipData? _relationshipData;
  List<CommunicationSession> _sessions = [];
  CommunicationSession? _currentSession;
  bool _isOnboardingComplete = false;
  String? _currentUserId;
  final InviteService _inviteService = InviteService();

  RelationshipData? get relationshipData => _relationshipData;
  List<CommunicationSession> get sessions => _sessions;
  CommunicationSession? get currentSession => _currentSession;
  bool get isOnboardingComplete => _isOnboardingComplete;
  String? get currentUserId => _currentUserId;
  bool get hasPartner => _relationshipData?.partnerB != null;

  Future<void> initialize() async {
    await _loadData();
    notifyListeners();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load onboarding status
    _isOnboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    
    // Load current user ID
    _currentUserId = prefs.getString('current_user_id');
    
    // Load relationship data
    final relationshipJson = prefs.getString('relationship_data');
    if (relationshipJson != null) {
      try {
        _relationshipData = RelationshipData.fromJson(jsonDecode(relationshipJson));
      } catch (e) {
        debugPrint('Error loading relationship data: $e');
      }
    }
    
    // Load sessions
    final sessionsJson = prefs.getStringList('communication_sessions') ?? [];
    _sessions = sessionsJson.map((json) {
      try {
        return CommunicationSession.fromJson(jsonDecode(json));
      } catch (e) {
        debugPrint('Error loading session: $e');
        return null;
      }
    }).where((session) => session != null).cast<CommunicationSession>().toList();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('onboarding_complete', _isOnboardingComplete);
    
    if (_currentUserId != null) {
      await prefs.setString('current_user_id', _currentUserId!);
    }
    
    if (_relationshipData != null) {
      await prefs.setString('relationship_data', jsonEncode(_relationshipData!.toJson()));
    }
    
    final sessionsJson = _sessions.map((session) => jsonEncode(session.toJson())).toList();
    await prefs.setStringList('communication_sessions', sessionsJson);
  }

  Future<void> completeOnboarding(Partner partner) async {
    _currentUserId = partner.id;
    
    if (partner.id == 'A') {
      // Partner A creates a new invite
      final inviteCode = await _inviteService.createInvite(partner);
      
      _relationshipData = RelationshipData(
        partnerA: partner,
        partnerB: Partner(
          id: 'B',
          name: '',
          gender: '',
          relationshipGoals: [],
          currentChallenges: [],
        ),
        createdAt: DateTime.now(),
        inviteCode: inviteCode,
      );
    } else {
      // Partner B should use joinWithInviteCode instead
      throw Exception('Partner B should use joinWithInviteCode method');
    }
    
    _isOnboardingComplete = true;
    await _saveData();
    notifyListeners();
  }

  Future<InviteJoinResult> joinWithInviteCode(String code, Partner partner) async {
    try {
      _currentUserId = partner.id;
      
      // Validate the invite code and get Partner A's data
      final result = await _inviteService.validateAndUseInvite(code, partner);
      
      if (result.isValid && result.partner != null) {
        _relationshipData = RelationshipData(
          partnerA: result.partner!,
          partnerB: partner,
          createdAt: DateTime.now(),
          inviteCode: code,
        );
        _isOnboardingComplete = true;
        await _saveData();
        notifyListeners();
        return InviteJoinResult.success();
      } else {
        return InviteJoinResult.failure(result.errorMessage ?? 'Invalid invite code');
      }
    } catch (e) {
      debugPrint('Error joining with invite code: $e');
      return InviteJoinResult.failure('An error occurred while joining. Please try again.');
    }
  }

  void startCommunicationSession() {
    if (_relationshipData == null || !hasPartner) return;
    
    _currentSession = CommunicationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      messages: [],
    );
    notifyListeners();
  }

  void addMessage(String speakerId, String content, MessageType type, {bool wasInterrupted = false}) {
    if (_currentSession == null) return;
    
    final message = Message(
      speakerId: speakerId,
      content: content,
      timestamp: DateTime.now(),
      type: type,
      wasInterrupted: wasInterrupted,
    );
    
    _currentSession!.messages.add(message);
    notifyListeners();
  }

  Future<void> endCommunicationSession({
    CommunicationScores? scores,
    String? reflection,
    List<String>? suggestedActivities,
  }) async {
    if (_currentSession == null) return;
    
    final completedSession = CommunicationSession(
      id: _currentSession!.id,
      startTime: _currentSession!.startTime,
      endTime: DateTime.now(),
      messages: _currentSession!.messages,
      scores: scores,
      reflection: reflection,
      suggestedActivities: suggestedActivities ?? [],
    );
    
    _sessions.add(completedSession);
    _currentSession = null;
    
    await _saveData();
    notifyListeners();
  }

  Partner? getCurrentPartner() {
    if (_relationshipData == null || _currentUserId == null) return null;
    
    if (_currentUserId == 'A') {
      return _relationshipData!.partnerA;
    } else if (_currentUserId == 'B') {
      return _relationshipData!.partnerB;
    }
    return null;
  }

  Partner? getOtherPartner() {
    if (_relationshipData == null || _currentUserId == null) return null;
    
    if (_currentUserId == 'A') {
      return _relationshipData!.partnerB;
    } else if (_currentUserId == 'B') {
      return _relationshipData!.partnerA;
    }
    return null;
  }

  List<CommunicationSession> getRecentSessions({int limit = 10}) {
    final completedSessions = _sessions.where((s) => s.isCompleted).toList();
    completedSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return completedSessions.take(limit).toList();
  }

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

  Future<void> clearAllData() async {
    _relationshipData = null;
    _sessions = [];
    _currentSession = null;
    _isOnboardingComplete = false;
    _currentUserId = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    notifyListeners();
  }
}