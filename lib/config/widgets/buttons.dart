import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../constants/theme_switch.dart';

class ModernMenuItem extends StatefulWidget {
  final Widget iconWidget;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isPrimaryAction;

  const ModernMenuItem({
    super.key,
    required this.iconWidget,
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
        ? ColorScheme.fromSeed(
        seedColor: Colors.red, brightness: theme.brightness)
        : baseColorScheme;

    final bool isHighlighted = _isHovered || _isPressed;

    final Color textColor;
    final Gradient? backgroundGradient;
    final List<BoxShadow>? boxShadow;

    if (widget.isPrimaryAction) {
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
      // iconColor = isHighlighted ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7); // RIMOSSO
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
                    widget.iconWidget,
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

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
                child: Icon(
                  theme.brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(theme.brightness),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
            ),
          ),
        );
      },
    );
  }
}



class CreateProjectButton extends StatelessWidget {
  final int projectCount;
  final VoidCallback onPressed;
  const CreateProjectButton({super.key, required this.projectCount, required this.onPressed});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.plus, size: 16, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 10),
                Text(
                  projectCount == 0 ? "Crea il tuo primo progetto" : "Nuovo Progetto",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NavigationButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

