import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onThemeToggle;
  final bool isDark;
  final bool showBackButton;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onThemeToggle,
    required this.isDark,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showBackButton)
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: theme.typography.body?.color?.withOpacity(0.6)),
            onPressed: () => context.pop(),
          ),
        Expanded(
          child: Row(
            children: [
              // Logo animato
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.accentColor.darker,
                            theme.accentColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.accentColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        FontAwesomeIcons.diagramProject,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              // Testi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Text(
                              title,
                              style: theme.typography.title
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Text(
                              subtitle,
                              style: theme.typography.body?.copyWith(
                                color: theme.typography.body?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onThemeToggle != null)
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.inactiveColor.withOpacity(0.2),
                    ),
                  ),
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: animation,
                          child: child,
                        );
                      },
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 25,
                        key: ValueKey(isDark),
                        color: theme.typography.body?.color,
                      ),
                    ),
                    onPressed: onThemeToggle,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}