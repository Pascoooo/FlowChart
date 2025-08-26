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
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
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

    if (widget.isPrimary && !widget.isLoading) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(SocialAuthButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gestione animazione shimmer in base allo stato
    if (widget.isPrimary && !widget.isLoading && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if ((!widget.isPrimary || widget.isLoading) && _shimmerController.isAnimating) {
      _shimmerController.stop();
      _shimmerController.reset();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isEnabled && !widget.isLoading) {
      setState(() => _isPressed = true);
      _scaleController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _resetPressState();
  }

  void _handleTapCancel() {
    _resetPressState();
  }

  void _resetPressState() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _scaleController.reverse();
    }
  }

  void _handleTap() {
    if (widget.isEnabled && !widget.isLoading) {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isInteractive = widget.isEnabled && !widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
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
                    color: _isPressed
                        ? theme.colorScheme.primary.withOpacity(0.5)
                        : theme.colorScheme.outline.withOpacity(0.2),
                    width: _isPressed ? 2.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isPrimary
                          ? theme.colorScheme.primary.withOpacity(_isPressed ? 0.4 : 0.3)
                          : theme.colorScheme.shadow.withOpacity(_isPressed ? 0.1 : 0.05),
                      blurRadius: widget.isPrimary ? (_isPressed ? 25 : 20) : (_isPressed ? 15 : 12),
                      offset: Offset(0, widget.isPrimary ? (_isPressed ? 6 : 8) : (_isPressed ? 2 : 4)),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Shimmer effect
                    if (widget.isPrimary && !widget.isLoading)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedBuilder(
                            animation: _shimmerAnimation,
                            builder: (context, child) {
                              return Transform.translate(
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
                              );
                            },
                          ),
                        ),
                      ),

                    // Clickable area - copre tutto il container
                    Positioned.fill(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        splashColor: widget.isPrimary
                            ? Colors.white.withOpacity(0.2)
                            : theme.colorScheme.primary.withOpacity(0.1),
                        highlightColor: widget.isPrimary
                            ? Colors.white.withOpacity(0.1)
                            : theme.colorScheme.primary.withOpacity(0.05),
                        mouseCursor: isInteractive
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        onTap: _handleTap,
                        onTapDown: _handleTapDown,
                        onTapUp: _handleTapUp,
                        onTapCancel: _handleTapCancel,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildContent(theme),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (widget.isLoading) {
      return Row(
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
      );
    }

    return Row(
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
        Flexible(
          child: Text(
            widget.text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: widget.isPrimary
                  ? Colors.white
                  : theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}