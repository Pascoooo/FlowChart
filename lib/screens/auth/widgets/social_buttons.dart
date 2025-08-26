import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialAuthButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? iconColor;
  final bool isPrimary;
  final bool isEnabled;

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.iconColor,
    this.isPrimary = false,
    this.isEnabled = true,
  });

  @override
  State<SocialAuthButton> createState() => _SocialAuthButtonState();
}

class _SocialAuthButtonState extends State<SocialAuthButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    if (widget.isPrimary) {
      _shimmerController.repeat();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: widget.isPrimary
                  ? LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8),
                ],
              )
                  : null,
              color: widget.isPrimary
                  ? null
                  : (isDark
                  ? theme.colorScheme.surfaceVariant.withOpacity(0.5)
                  : theme.colorScheme.surface),
              borderRadius: BorderRadius.circular(18),
              border: widget.isPrimary
                  ? null
                  : Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isPrimary
                      ? theme.colorScheme.primary.withOpacity(0.3)
                      : theme.colorScheme.shadow.withOpacity(0.05),
                  blurRadius: widget.isPrimary ? 20 : 12,
                  offset: Offset(0, widget.isPrimary ? 8 : 4),
                ),
              ],
            ),
              child: Stack(
                  children: [
              if (widget.isPrimary && !widget.isLoading)
              IgnorePointer(
              child: AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Transform.translate(
                      offset: Offset(_shimmerAnimation.value * 100, 0),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.2),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              ),
              ),
                // Button content
                Positioned.fill(
                child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                borderRadius: BorderRadius.circular(18),
                mouseCursor: widget.isEnabled && !widget.isLoading
                ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                onTap: widget.isEnabled && !widget.isLoading ? widget.onPressed : null,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: widget.isLoading
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.isPrimary
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Accesso in corso...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: widget.isPrimary
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            widget.icon,
                            size: 22,
                            color: widget.iconColor ??
                                (widget.isPrimary
                                    ? Colors.white
                                    : theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            widget.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: widget.isPrimary
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}