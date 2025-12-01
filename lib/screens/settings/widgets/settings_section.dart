/// Contenitore di sezione per gruppi di impostazioni.
/// Fornisce header, stato opzionale e inserisce divisori tra i figli.

import 'package:fluent_ui/fluent_ui.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final Widget? status;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    this.status,
    required this.children,
  });

  /// Costruisce il contenitore della sezione con header e corpo,
  /// applicando bordi e divisori per separare i widget figli.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.inactiveColor.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.typography.subtitle?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (status != null) status!,
              ],
            ),
          ),
          const Divider(size: 1.0),
          // Body
          ..._withDividers(children),
        ],
      ),
    );
  }

  /// Inserisce un Divider tra ogni widget della lista,
  /// mantenendo l'ordine e saltando il divider finale.
  List<Widget> _withDividers(List<Widget> items) {
    if (items.isEmpty) return items;
    final List<Widget> out = [];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i < items.length - 1) {
        out.add(const Divider(size: 0.5));
      }
    }
    return out;
  }
}
