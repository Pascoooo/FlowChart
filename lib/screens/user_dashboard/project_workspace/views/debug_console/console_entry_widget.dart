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
                  fontSize: 15, // ✅ Aumentato da 13 a 15px per leggibilità
                  height: 1.6,
                  fontWeight: style.bold ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.4,
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

    // ✅ MIGLIORATO: Colori più leggibili e background meno invadenti
    final consoleColor = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
    final consoleBackground = isDark
      ? const Color(0xFF1A237E).withValues(alpha: 0.15) // ✅ Ridotto alpha da 0.3 a 0.15
      : const Color(0xFFE3F2FD).withValues(alpha: 0.5); // ✅ Ridotto alpha
    final consoleBorderColor = isDark ? const Color(0xFF1976D2).withValues(alpha: 0.4) : const Color(0xFF90CAF9).withValues(alpha: 0.6);

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
        // ✅ Errore NON bloccante (warning arancione)
        return _ConsoleEntryStyle(
          color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
          bold: true,
          withBackground: true,
          backgroundColor: isDark
            ? const Color(0xFFE65100).withValues(alpha: 0.2)
            : const Color(0xFFFFF3E0),
          borderColor: isDark ? const Color(0xFFFB8C00) : const Color(0xFFFFCC80),
          icon: FluentIcons.warning,
        );
      case ConsoleEntryType.blockingError:
        // ✅ Errore BLOCCANTE (rosso critico)
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
