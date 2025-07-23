import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodCheckinDialog extends StatelessWidget {
  final List<_MoodOption> moods = const [
    _MoodOption('😊', 'Happy'),
    _MoodOption('😐', 'Neutral'),
    _MoodOption('😔', 'Sad'),
    _MoodOption('😡', 'Angry'),
    _MoodOption('😰', 'Anxious'),
    _MoodOption('🥰', 'Loved'),
    _MoodOption('🤔', 'Thoughtful'),
  ];

  const MoodCheckinDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How are you feeling today?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: moods.map((mood) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(mood.emoji, style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text(
                          mood.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodOption {
  final String emoji;
  final String label;
  const _MoodOption(this.emoji, this.label);
}
