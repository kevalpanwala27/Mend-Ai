import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart' show canLaunch, launch;
import '../../providers/firebase_app_state.dart';
import '../../theme/app_theme.dart';
import '../main/home_screen.dart';

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _codeShared = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invite code copied to clipboard!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareCode(String code) {
    final message =
        '''
🌟 Join me on Mend!

I've started using Mend, an AI-powered couples therapy app to help us communicate better and strengthen our relationship.

Your invite code: $code

Download Mend and use this code to join our relationship space. Let's work on growing together! 💕

#MendApp #RelationshipGrowth
    ''';

    Share.share(message);
    setState(() => _codeShared = true);
  }

  void _shareViaSMS(String code, String partnerName) async {
    final message = Uri.encodeComponent(
      "Hi! It's $partnerName. I just downloaded Mend, an app to help us communicate better. Join me by entering this invite code: $code. Download Mend and let's start our journey together!",
    );
    final uri = 'sms:?body=$message';
    if (await canLaunch(uri)) {
      await launch(uri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open SMS app.')));
    }
  }

  void _shareViaEmail(String code, String partnerName) async {
    final subject = Uri.encodeComponent('Join me on Mend!');
    final body = Uri.encodeComponent(
      "Hi! It's $partnerName. I just downloaded Mend, an app to help us communicate better. Join me by entering this invite code: $code. Download Mend and let's start our journey together!",
    );
    final uri = 'mailto:?subject=$subject&body=$body';
    if (await canLaunch(uri)) {
      await launch(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  void _continueToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAppState>(
      builder: (context, appState, child) {
        final inviteCode = appState.relationshipData?['inviteCode'] ?? '';
        final partnerName = appState.getCurrentPartner()?.name ?? 'You';
        final partnerB = appState.relationshipData?['partnerB'];

        // If partnerB is present, go to HomeScreen automatically
        if (partnerB != null) {
          Future.microtask(() {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Success icon
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              size: 60,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Welcome message
                    Text(
                      'Welcome to Mend, $partnerName!',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Your relationship space is ready. Share this invite code with your partner to begin your journey together.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // Invite code display
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Your Invite Code',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            inviteCode,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(inviteCode),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('Copy'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _shareCode(inviteCode),
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text('Share'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _shareViaSMS(inviteCode, partnerName),
                                icon: const Icon(Icons.sms, size: 18),
                                label: const Text('SMS'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _shareViaEmail(inviteCode, partnerName),
                                icon: const Icon(Icons.email, size: 18),
                                label: const Text('Email'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'How to invite your partner:',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionItem(
                            '1. Share the invite code above with your partner',
                          ),
                          _buildInstructionItem(
                            '2. Have them download Mend on their phone',
                          ),
                          _buildInstructionItem(
                            '3. They select "Join Your Partner" on the welcome screen',
                          ),
                          _buildInstructionItem(
                            '4. Enter the code and complete their profile',
                          ),
                          _buildInstructionItem(
                            '5. You\'ll both be connected and ready to start!',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Action buttons
                    Column(
                      children: [
                        if (_codeShared) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Invite shared! Your partner can now join.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _continueToApp,
                            child: const Text('Continue to App'),
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => _shareCode(inviteCode),
                            child: const Text('Share Code Again'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionItem(String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 8, right: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              instruction,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
