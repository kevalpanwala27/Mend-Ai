import 'package:flutter/foundation.dart';

class Partner {
  final String id;
  final String name;
  final String gender;
  final List<String> relationshipGoals;
  final List<String> currentChallenges;
  final String? customGoal;
  final String? customChallenge;

  Partner({
    required this.id,
    required this.name,
    required this.gender,
    required this.relationshipGoals,
    required this.currentChallenges,
    this.customGoal,
    this.customChallenge,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'relationshipGoals': relationshipGoals,
      'currentChallenges': currentChallenges,
      'customGoal': customGoal,
      'customChallenge': customChallenge,
    };
  }

  factory Partner.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields
      final id = json['id'] as String?;
      final name = json['name'] as String?;
      final gender = json['gender'] as String?;
      
      if (id == null || id.isEmpty) {
        throw ArgumentError('Invalid or missing id in Partner.fromJson');
      }
      if (name == null || name.isEmpty) {
        throw ArgumentError('Invalid or missing name in Partner.fromJson');
      }
      if (gender == null || gender.isEmpty) {
        throw ArgumentError('Invalid or missing gender in Partner.fromJson');
      }
      
      // Safely parse arrays with null checks
      List<String> relationshipGoals = [];
      if (json['relationshipGoals'] is List) {
        try {
          relationshipGoals = List<String>.from(json['relationshipGoals']);
        } catch (e) {
          debugPrint('Warning: Invalid relationshipGoals format, using empty list');
        }
      }
      
      List<String> currentChallenges = [];
      if (json['currentChallenges'] is List) {
        try {
          currentChallenges = List<String>.from(json['currentChallenges']);
        } catch (e) {
          debugPrint('Warning: Invalid currentChallenges format, using empty list');
        }
      }
      
      return Partner(
        id: id,
        name: name,
        gender: gender,
        relationshipGoals: relationshipGoals,
        currentChallenges: currentChallenges,
        customGoal: json['customGoal'] as String? ?? '',
        customChallenge: json['customChallenge'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Error parsing Partner from JSON: $e');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}

class RelationshipData {
  final Partner partnerA;
  final Partner partnerB;
  final DateTime createdAt;
  final String inviteCode;

  RelationshipData({
    required this.partnerA,
    required this.partnerB,
    required this.createdAt,
    required this.inviteCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'partnerA': partnerA.toJson(),
      'partnerB': partnerB.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'inviteCode': inviteCode,
    };
  }

  factory RelationshipData.fromJson(Map<String, dynamic> json) {
    return RelationshipData(
      partnerA: Partner.fromJson(json['partnerA']),
      partnerB: Partner.fromJson(json['partnerB']),
      createdAt: DateTime.parse(json['createdAt']),
      inviteCode: json['inviteCode'],
    );
  }
}