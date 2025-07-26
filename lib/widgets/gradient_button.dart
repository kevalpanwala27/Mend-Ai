import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final bool isSecondary;
  final double? fontSize;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
    this.padding,
    this.isSecondary = false,
    this.fontSize,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: widget.onPressed != null ? _onTapCancel : null,
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height ?? 56,
              padding: widget.padding ??
                  const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                    vertical: AppTheme.spacingM,
                  ),
              decoration: BoxDecoration(
                gradient: widget.isSecondary
                    ? null
                    : const LinearGradient(
                        colors: [
                          AppTheme.gradientStart,
                          AppTheme.gradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: widget.isSecondary ? Colors.transparent : null,
                border: widget.isSecondary
                    ? Border.all(
                        color: AppTheme.primary,
                        width: 2,
                      )
                    : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                boxShadow: widget.isSecondary
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: widget.isLoading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.isSecondary
                                ? AppTheme.primary
                                : Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: widget.icon != null && widget.text.isNotEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.icon,
                                  color: widget.isSecondary
                                      ? AppTheme.primary
                                      : Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Flexible(
                                  child: Text(
                                    widget.text,
                                    style: TextStyle(
                                      color: widget.isSecondary
                                          ? AppTheme.primary
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: widget.fontSize ?? 16,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            )
                          : widget.icon != null
                              ? Icon(
                                  widget.icon,
                                  color: widget.isSecondary
                                      ? AppTheme.primary
                                      : Colors.white,
                                  size: 20,
                                )
                              : Text(
                                  widget.text,
                                  style: TextStyle(
                                    color: widget.isSecondary
                                        ? AppTheme.primary
                                        : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: widget.fontSize ?? 16,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                    ),
            ),
          );
        },
      ),
    );
  }
}