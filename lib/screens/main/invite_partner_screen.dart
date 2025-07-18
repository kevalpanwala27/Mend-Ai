import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_state.dart';

class InvitePartnerScreen extends StatelessWidget {
  const InvitePartnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final relationshipData = appState.relationshipData;
        final currentPartner = appState.getCurrentPartner();

        if (relationshipData == null) {
          // True error: show fallback with retry
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Something went wrong. Please try again.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => appState.initialize(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Always show the invite UI if relationshipData exists
        final partnerName = currentPartner?.name ?? 'You';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Invite Your Partner'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Success message
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome, $partnerName!',
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your profile is set up. Now let\'s invite your partner to join.',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'Share Your Invite Code',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Invite code display
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invite Code',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                relationshipData.inviteCode,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      letterSpacing: 4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: relationshipData.inviteCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Invite code copied to clipboard',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy code',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Share buttons
                  Text(
                    'Mend works best with your partner! Send them an invite to join your relationship space.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invite message preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getInviteMessage(
                        relationshipData.inviteCode,
                        partnerName: partnerName,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _shareInvite(
                        relationshipData.inviteCode,
                        partnerName: partnerName,
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('Share Invite'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyInviteMessage(
                        context,
                        relationshipData.inviteCode,
                        partnerName: partnerName,
                      ),
                      icon: const Icon(Icons.message),
                      label: const Text('Copy Message'),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. Share the invite code with your partner\n'
                          '2. They download Mend and select "Join Your Partner"\n'
                          '3. They enter the code and complete their profile\n'
                          '4. You\'ll both be connected and ready to start!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Refresh button
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        // Refresh the screen to check for partner
                        appState.initialize();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check if partner joined'),
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

  void _shareInvite(String inviteCode, {String? partnerName}) {
    final message = _getInviteMessage(inviteCode, partnerName: partnerName);
    Share.share(message);
  }

  void _copyInviteMessage(
    BuildContext context,
    String inviteCode, {
    String? partnerName,
  }) {
    final message = _getInviteMessage(inviteCode, partnerName: partnerName);
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getInviteMessage(String inviteCode, {String? partnerName}) {
    final greeting = partnerName != null && partnerName.isNotEmpty
        ? 'Hi $partnerName,'
        : 'Hi!';
    return '''$greeting I just downloaded Mend, an app to help us communicate better. Join me by downloading the app and using this invite code: $inviteCode

Mend is an AI-powered relationship companion that guides our conversations and helps us resolve conflicts together. Looking forward to strengthening our relationship with you! ❤️''';
  }
}
