import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AITherapistAvatar extends StatelessWidget {
  final double size;
  const AITherapistAvatar({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated glowing orb
          Lottie.asset(
            'assets/lottie/ai_orb.json',
            repeat: true,
            animate: true,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
          // (Optional) Subtle face overlay for future upgrades
          // Positioned(
          //   child: Icon(Icons.face, color: Colors.white.withOpacity(0.15), size: size * 0.5),
          // ),
        ],
      ),
    );
  }
}
