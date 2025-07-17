import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../chat/voice_chat_screen.dart';
import '../main/insights_dashboard_screen.dart';
import 'invite_partner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (!appState.hasPartner) {
          return const InvitePartnerScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mend'),
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section
                  _buildWelcomeSection(context, appState),

                  const SizedBox(height: 32),

                  // Partner status
                  _buildPartnerSection(context, appState),

                  const SizedBox(height: 32),

                  // Recent activity
                  _buildRecentActivity(context, appState),

                  const Spacer(),

                  // Start conversation button
                  _buildStartConversationButton(context, appState),
                ],
              ),
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VoiceChatScreen()),
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
