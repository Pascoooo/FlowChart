import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ModernMenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isPrimaryAction;

  const ModernMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
    this.isPrimaryAction = false,
  });

  @override
  State<ModernMenuItem> createState() => _ModernMenuItemState();
}

class _ModernMenuItemState extends State<ModernMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColorScheme = theme.colorScheme;
    final colorScheme = widget.isDestructive
        ? ColorScheme.fromSeed(seedColor: Colors.red, brightness: theme.brightness)
        : baseColorScheme;

    final bool isHighlighted = _isHovered || _isPressed;

    final Color iconColor;
    final Color textColor;
    final Gradient? backgroundGradient;
    final List<BoxShadow>? boxShadow;

    if (widget.isPrimaryAction) {
      iconColor = baseColorScheme.onPrimary;
      textColor = baseColorScheme.onPrimary;
      backgroundGradient = LinearGradient(
        colors: [
          baseColorScheme.primary,
          baseColorScheme.secondary,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      boxShadow = [
        BoxShadow(
          color: baseColorScheme.primary.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      iconColor = isHighlighted
          ? colorScheme.primary
          : colorScheme.onSurface.withOpacity(0.7);
      textColor = isHighlighted
          ? colorScheme.primary
          : baseColorScheme.onSurface.withOpacity(0.8);
      backgroundGradient = isHighlighted
          ? LinearGradient(colors: [
        colorScheme.primary.withOpacity(0.1),
        colorScheme.primary.withOpacity(0.05),
      ])
          : null;
      boxShadow = null;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTapDown: (_) {
                setState(() => _isPressed = true);
                _scaleController.forward();
              },
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _scaleController.reverse();
                widget.onTap();
              },
              onTapCancel: () {
                setState(() => _isPressed = false);
                _scaleController.reverse();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: backgroundGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: boxShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    FaIcon(widget.icon, size: 18, color: iconColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
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
}