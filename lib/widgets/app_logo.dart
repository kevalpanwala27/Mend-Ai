import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatefulWidget {
  final double size;
  final bool animate;

  const AppLogo({
    super.key,
    this.size = 120,
    this.animate = true,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    if (widget.animate) {
      _pulseController.repeat(reverse: true);
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating circle
          if (widget.animate)
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.1),
                          AppTheme.secondary.withOpacity(0.1),
                          AppTheme.accent.withOpacity(0.1),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
          
          // Main logo container
          AnimatedBuilder(
            animation: widget.animate ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: widget.size * 0.8,
                  height: widget.size * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.gradientStart,
                        AppTheme.gradientEnd,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Heart icon
                      Icon(
                        Icons.favorite_rounded,
                        size: widget.size * 0.35,
                        color: Colors.white,
                      ),
                      
                      // Connecting lines (representing communication)
                      Positioned(
                        top: widget.size * 0.15,
                        left: widget.size * 0.25,
                        child: Container(
                          width: widget.size * 0.3,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: widget.size * 0.15,
                        right: widget.size * 0.25,
                        child: Container(
                          width: widget.size * 0.3,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      
                      // Small circles representing partners
                      Positioned(
                        top: widget.size * 0.12,
                        left: widget.size * 0.12,
                        child: Container(
                          width: widget.size * 0.1,
                          height: widget.size * 0.1,
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: widget.size * 0.12,
                        right: widget.size * 0.12,
                        child: Container(
                          width: widget.size * 0.1,
                          height: widget.size * 0.1,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}