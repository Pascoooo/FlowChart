import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
