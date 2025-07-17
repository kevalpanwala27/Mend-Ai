import 'package:flutter/foundation.dart';
import '../models/partner.dart';
import 'firestore_invite_service.dart';

// Re-export for backwards compatibility
export 'firestore_invite_service.dart' show InviteValidationResult;

class InviteService {
  final FirestoreInviteService _firestoreService = FirestoreInviteService();
  
  // Generate a unique 6-character invite code
  String generateInviteCode() {
    return _firestoreService.generateInviteCode();
  }

  // Create an invite code for Partner A
  Future<String> createInvite(Partner partnerA) async {
    try {
      return await _firestoreService.createInvite(partnerA);
    } catch (e) {
      debugPrint('Error creating invite: $e');
      throw Exception('Failed to create invite code: $e');
    }
  }

  // Validate and use an invite code for Partner B
  Future<InviteValidationResult> validateAndUseInvite(String inviteCode, Partner partnerB) async {
    try {
      return await _firestoreService.validateAndUseInvite(inviteCode, partnerB);
    } catch (e) {
      debugPrint('Error validating invite: $e');
      return InviteValidationResult.invalid('An error occurred while validating the code. Please try again.');
    }
  }

  // Get invite details (for Partner A to check status)
  Future<Map<String, dynamic>?> getInviteStatus(String inviteCode) async {
    try {
      return await _firestoreService.getInviteStatus(inviteCode);
    } catch (e) {
      debugPrint('Error getting invite status: $e');
      return null;
    }
  }

  // Get all user invites
  Future<List<Map<String, dynamic>>> getUserInvites() async {
    try {
      return await _firestoreService.getUserInvites();
    } catch (e) {
      debugPrint('Error getting user invites: $e');
      return [];
    }
  }

  // Clean up expired invites
  Future<void> cleanupExpiredInvites() async {
    try {
      await _firestoreService.cleanupExpiredInvites();
    } catch (e) {
      debugPrint('Error cleaning up expired invites: $e');
    }
  }

  // Delete a specific invite
  Future<void> deleteInvite(String inviteCode) async {
    try {
      await _firestoreService.deleteInvite(inviteCode);
    } catch (e) {
      debugPrint('Error deleting invite: $e');
    }
  }

  // For testing: Clear all invites (now deprecated in favor of Firebase Console)
  @Deprecated('Use Firebase Console to manage data instead')
  Future<void> clearAllInvites() async {
    debugPrint('clearAllInvites is deprecated. Use Firebase Console to manage data.');
  }
}