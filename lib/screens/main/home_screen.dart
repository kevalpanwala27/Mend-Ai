import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_state.dart';
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../chat/voice_chat_screen.dart';
import '../main/insights_dashboard_screen.dart';
import 'invite_partner_screen.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'session_waiting_room_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('HomeScreen: build called');
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Remove hasPartner/relationshipData check. Always show session-based UI.
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mend Home'),
            actions: [
              IconButton(
                icon: const Icon(Icons.insights),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InsightsDashboardScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Welcome section
                _buildWelcomeSection(context, appState),

                const SizedBox(height: 32),

                // Partner status (optional, can be removed if not needed)
                //_buildPartnerSection(context, appState),

                //const SizedBox(height: 32),

                // Recent activity (optional, can be removed if not needed)
                //_buildRecentActivity(context, appState),

                //const Spacer(),

                // Start conversation button (shows prompt to use session flow)
                _buildStartConversationButton(context, appState),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showStartSessionDialog(context),
                          child: const Text('Start New Session'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showJoinSessionDialog(context),
                          child: const Text('Join Session'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection(BuildContext context, AppState appState) {
    final currentPartner = appState.getCurrentPartner();
    final timeOfDay = DateTime.now().hour;
    String greeting = 'Good morning';
    if (timeOfDay >= 12 && timeOfDay < 17) {
      greeting = 'Good afternoon';
    } else if (timeOfDay >= 17) {
      greeting = 'Good evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${currentPartner?.name ?? 'there'}!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Ready to strengthen your relationship today?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerSection(BuildContext context, AppState appState) {
    final currentPartner = appState.getCurrentPartner();
    final otherPartner = appState.getOtherPartner();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.getPartnerColor(currentPartner?.id ?? 'A'),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentPartner?.name ?? 'You',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.getPartnerColor(otherPartner?.id ?? 'B'),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    otherPartner?.name ?? 'Partner',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Both partners are connected and ready for guided conversations.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, AppState appState) {
    final recentSessions = appState.getRecentSessions(limit: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        if (recentSessions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your first guided conversation to begin your journey together.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...recentSessions.map(
            (session) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.chat,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text('Conversation Session'),
                subtitle: Text(
                  'Duration: ${session.duration.inMinutes} minutes\n'
                  '${_formatDate(session.startTime)}',
                ),
                trailing: session.scores != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            color: AppTheme.successGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStartConversationButton(
    BuildContext context,
    AppState appState,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // All sessions should use the session code flow now.
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => const VoiceChatScreen()),
          // );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please use "Start New Session" or "Join Session" below.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.mic),
        label: const Text('Start Guided Conversation'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  void _showStartSessionDialog(BuildContext context) {
    final sessionCode = _generateSessionCode();
    final userId = context.read<FirebaseAppState>().user?.uid ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Session Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sessionCode,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: sessionCode));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session code copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Add share logic
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Share this code with your partner so you can both join the same session.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionWaitingRoomScreen(
                          sessionCode: sessionCode,
                          userId: userId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Waiting Room'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinSessionDialog(BuildContext context) {
    final controller = TextEditingController();
    final userId = context.read<FirebaseAppState>().user?.uid ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Enter Session Code',
                  hintText: '6-character code',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionWaitingRoomScreen(
                          sessionCode: controller.text.toUpperCase(),
                          userId: userId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Join'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _generateSessionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today at ${_formatTime(date)}';
    } else if (sessionDate == yesterday) {
      return 'Yesterday at ${_formatTime(date)}';
    } else {
      return '${date.month}/${date.day}/${date.year} at ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
