import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../constants/theme_switch.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.inactiveColor.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    RotationTransition(turns: animation, child: child),
                child: Icon(
                  size: 25,
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(isDark),
                  color: theme.typography.body?.color,
                ),
              ),
              onPressed: () =>
                  Provider.of<ThemeProvider>(context, listen: false)
                      .toggleTheme(),
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

  const CreateProjectButton({
    super.key,
    required this.projectCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final primaryColor = theme.accentColor.darker;
    final secondaryColor = theme.accentColor;

    return Button(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: ButtonState.all(EdgeInsets.zero),
        backgroundColor: ButtonState.all(Colors.transparent),
        // Aggiungiamo questa riga per conformare il bordo del bottone base
        // alla nostra decorazione con angoli arrotondati.
        shape: ButtonState.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        ),
        shadowColor: ButtonState.resolveWith((states) {
          if (states.isHovering) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.transparent;
        }),
        elevation: ButtonState.resolveWith((states) {
          if (states.isHovering) {
            return 8.0;
          }
          return 0.0;
        }),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               Icon(FontAwesomeIcons.plus, size: 16, color: theme.brightness == Brightness.dark ? Colors.black : Colors.white),
              const SizedBox(width: 10),
              Text(
                projectCount == 0
                    ? "Crea il tuo primo progetto"
                    : "Nuovo Progetto",
                style: theme.typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
