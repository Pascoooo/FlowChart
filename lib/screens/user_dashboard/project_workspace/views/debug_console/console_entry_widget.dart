import 'package:fluent_ui/fluent_ui.dart';
import 'console_models.dart';

/// Widget per renderizzare una singola entry della console
class ConsoleEntryWidget extends StatelessWidget {
  final ConsoleEntry entry;

  const ConsoleEntryWidget({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final style = _getStyleForEntry(theme, entry.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: style.withBackground ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : EdgeInsets.zero,
        decoration: style.withBackground
            ? BoxDecoration(
                color: style.backgroundColor,
                borderRadius: BorderRadius.circular(6),
                border: style.borderColor != null
                    ? Border.all(color: style.borderColor!, width: 1.5)
                    : null,
              )
            : null,
        child: SelectableText.rich(
          TextSpan(
            children: [
              if (style.icon != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      style.icon,
                      size: 14,
                      color: style.color,
                    ),
                  ),
                ),
              TextSpan(
                text: entry.text,
                style: TextStyle(
                  color: style.color,
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ConsoleEntryStyle _getStyleForEntry(FluentThemeData theme, ConsoleEntryType type) {
    final isDark = theme.brightness == Brightness.dark;

    // Colore blu/celestino uniforme per tutti i messaggi della console
    final consoleColor = isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0288D1);
    final consoleBackground = isDark
      ? const Color(0xFF1A237E).withValues(alpha: 0.3)
      : const Color(0xFFE3F2FD);
    final consoleBorderColor = isDark ? const Color(0xFF1976D2) : const Color(0xFF90CAF9);

    switch (type) {
      case ConsoleEntryType.system:
        return _ConsoleEntryStyle(
          color: theme.resources.textFillColorSecondary,
          bold: false,
        );
      case ConsoleEntryType.info:
        return _ConsoleEntryStyle(
          color: consoleColor,
          bold: true,
          withBackground: true,
          backgroundColor: consoleBackground,
          borderColor: consoleBorderColor,
          icon: FluentIcons.info,
        );
      case ConsoleEntryType.prompt:
        return _ConsoleEntryStyle(
          color: consoleColor,
          bold: true,
          icon: FluentIcons.text_field,
        );
      case ConsoleEntryType.userInput:
        return _ConsoleEntryStyle(
          color: isDark ? Colors.white : Colors.black,
          bold: false,
          icon: FluentIcons.chevron_right,
        );
      case ConsoleEntryType.success:
        return _ConsoleEntryStyle(
          color: consoleColor,
          bold: true,
          withBackground: true,
          backgroundColor: consoleBackground,
          borderColor: consoleBorderColor,
        );
      case ConsoleEntryType.error:
        return _ConsoleEntryStyle(
          color: isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828),
          bold: true,
          withBackground: true,
          backgroundColor: isDark
            ? const Color(0xFFB71C1C).withValues(alpha: 0.3)
            : const Color(0xFFFFEBEE),
          borderColor: isDark ? const Color(0xFFD32F2F) : const Color(0xFFE57373),
          icon: FluentIcons.error_badge,
        );
      case ConsoleEntryType.output:
        return _ConsoleEntryStyle(
          color: consoleColor,
          bold: true,
          withBackground: true,
          backgroundColor: consoleBackground,
          borderColor: consoleBorderColor,
        );
    }
  }
}

class _ConsoleEntryStyle {
  final Color color;
  final bool bold;
  final IconData? icon;
  final bool withBackground;
  final Color? backgroundColor;
  final Color? borderColor;

  _ConsoleEntryStyle({
    required this.color,
    this.bold = false,
    this.icon,
    this.withBackground = false,
    this.backgroundColor,
    this.borderColor,
  });
}
