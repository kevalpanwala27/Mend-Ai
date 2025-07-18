import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/voice_chat_screen.dart';

class SessionWaitingRoomScreen extends StatefulWidget {
  final String sessionCode;
  final String userId;

  const SessionWaitingRoomScreen({
    Key? key,
    required this.sessionCode,
    required this.userId,
  }) : super(key: key);

  @override
  State<SessionWaitingRoomScreen> createState() =>
      _SessionWaitingRoomScreenState();
}

class _SessionWaitingRoomScreenState extends State<SessionWaitingRoomScreen> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _sessionStream;

  @override
  void initState() {
    super.initState();
    _sessionStream = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionCode)
        .snapshots();
    _joinSession();
  }

  Future<void> _joinSession() async {
    final sessionRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(widget.sessionCode);
    final sessionDoc = await sessionRef.get();
    if (!sessionDoc.exists) {
      // Create session document with this user as first participant
      await sessionRef.set({
        'participants': [widget.userId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Add this user to participants if not already present
      final data = sessionDoc.data()!;
      final List participants = data['participants'] ?? [];
      if (!participants.contains(widget.userId)) {
        await sessionRef.update({
          'participants': FieldValue.arrayUnion([widget.userId]),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waiting Room')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _sessionStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          final participants =
              (data?['participants'] as List?)?.cast<String>() ?? [];
          final isReady = participants.length >= 2;

          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Session Code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.sessionCode,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 32),
                if (!isReady) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'Waiting for your partner to join...',
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 24),
                  const Text(
                    'Both partners are here! You can start your session.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VoiceSessionScreen(
                              sessionCode: widget.sessionCode,
                              userId: widget.userId,
                            ),
                          ),
                        );
                      },
                      child: const Text('Start Session'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
