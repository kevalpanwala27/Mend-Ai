import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final bool enabled;

  const CustomTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.helperText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.enabled = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    });
    
    if (_isFocused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.labelText != null) ...[
                Text(
                  widget.labelText!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
              ],
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: TextFormField(
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  onTap: widget.onTap,
                  validator: widget.validator,
                  keyboardType: widget.keyboardType,
                  obscureText: widget.obscureText,
                  readOnly: widget.readOnly,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  focusNode: widget.focusNode,
                  textInputAction: widget.textInputAction,
                  onEditingComplete: widget.onEditingComplete,
                  enabled: widget.enabled,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    helperText: widget.helperText,
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: widget.suffixIcon,
                    filled: true,
                    fillColor: widget.enabled 
                        ? AppTheme.surface 
                        : AppTheme.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingM,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.interruptionColor,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.interruptionColor,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      borderSide: const BorderSide(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}