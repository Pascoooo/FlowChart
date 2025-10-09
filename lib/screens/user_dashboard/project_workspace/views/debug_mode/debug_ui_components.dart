import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 🎨 Tab Button - Pulsante per tab switching
class DebugTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const DebugTabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final isHovering = states.isHovered;

        Color backgroundColor;
        Color foregroundColor;

        if (isSelected) {
          backgroundColor = theme.accentColor.defaultBrushFor(theme.brightness);
          foregroundColor = theme.brightness == Brightness.light
              ? Colors.white
              : Colors.black;
        } else if (isHovering) {
          backgroundColor = theme.resources.subtleFillColorSecondary;
          foregroundColor = theme.resources.textFillColorPrimary;
        } else {
          backgroundColor = Colors.transparent;
          foregroundColor = theme.resources.textFillColorSecondary;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, size: 14, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 🎨 Debug Expander - Expander con icona
class DebugExpander extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool initiallyExpanded;
  final Widget child;

  const DebugExpander({
    super.key,
    required this.title,
    required this.icon,
    required this.initiallyExpanded,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Expander(
      initiallyExpanded: initiallyExpanded,
      header: Row(
        children: [
          FaIcon(
            icon,
            size: 14,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.typography.bodyStrong?.copyWith(
              fontSize: 14,
            ),
          ),
        ],
      ),
      content: child,
    );
  }
}

/// 🎨 Detail Row - Riga di dettaglio label/value
class DebugDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;

  const DebugDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isNotEmpty ? value : '–',
              style: TextStyle(
                fontFamily: isCode ? 'monospace' : null,
                fontSize: 13,
                color: theme.resources.textFillColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 Variable Row - Riga variabile con 3 colonne (Nome, Tipo, Valore)
class DebugVariableRow extends StatelessWidget {
  final String name;
  final String type;
  final String? value;

  const DebugVariableRow({
    super.key,
    required this.name,
    required this.type,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final displayValue = value ?? '-';
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.resources.dividerStrokeColorDefault.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Colonna NOME
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF569CD6) : const Color(0xFF0078D4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0078D4),
                      fontFamily: 'Consolas',
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Colonna TIPO - Centrato con larghezza fissa
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getTypeColor(type, isDark).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _getTypeColor(type, isDark),
                    fontFamily: 'Consolas',
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Colonna VALORE - Allineato a sinistra
          Expanded(
            flex: 4,
            child: SelectableText(
              displayValue,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: value == null
                  ? theme.resources.textFillColorTertiary
                  : (isDark ? const Color(0xFFCE9178) : const Color(0xFF811F3F)),
                fontStyle: value == null ? FontStyle.italic : FontStyle.normal,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'int':
      case 'integer':
        return isDark ? const Color(0xFFB5CEA8) : const Color(0xFF267F99);
      case 'double':
      case 'float':
        return isDark ? const Color(0xFF4EC9B0) : const Color(0xFF008080);
      case 'string':
        return isDark ? const Color(0xFFCE9178) : const Color(0xFF811F3F);
      case 'bool':
      case 'boolean':
        return isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
      default:
        return isDark ? const Color(0xFFD4D4D4) : const Color(0xFF666666);
    }
  }
}
