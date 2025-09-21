import 'package:flutter/material.dart';

/// A button to toggle the visibility of the grid.
class GridToggleButton extends StatelessWidget {
  final bool showGrid;
  final VoidCallback onToggle;

  const GridToggleButton({super.key, required this.showGrid, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: showGrid ? 'Nascondi griglia' : 'Mostra griglia',
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: IconButton(
          onPressed: onToggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              showGrid ? Icons.grid_off_rounded : Icons.grid_on_rounded,
              key: ValueKey<bool>(showGrid),
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}