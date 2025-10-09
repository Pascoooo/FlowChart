import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
// AnimatedSwitcher, ScaleTransition, etc., sono parte di Flutter e non necessitano di import specifici se 'package:flutter/widgets.dart' è già importato.

/// A button to toggle the visibility of the grid, styled for Fluent UI.
class GridToggleButton extends StatelessWidget {
  final bool showGrid;
  final VoidCallback onToggle;

  const GridToggleButton({super.key, required this.showGrid, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Ottieni il tema di Fluent UI
    final theme = FluentTheme.of(context);

    return Tooltip(
      message: showGrid ? 'Nascondi griglia' : 'Mostra griglia',
      child: Container(
        decoration: BoxDecoration(
          // Material `surface` -> Fluent `cardColor`
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // Usa un colore generico per l'ombra
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          // Material `dividerColor` -> Colore standard di Fluent per i bordi
          border: Border.all(color: theme.resources.cardStrokeColorDefault),
        ),
        child: IconButton(
          onPressed: onToggle,
          // Rendi trasparente lo sfondo del bottone per mostrare la decorazione del Container
          style: ButtonStyle(
            backgroundColor: ButtonState.all(Colors.transparent),
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(

              showGrid ? Icons.grid_off_rounded : Icons.grid_on_rounded,
              key: ValueKey<bool>(showGrid),
              color: theme.accentColor,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}