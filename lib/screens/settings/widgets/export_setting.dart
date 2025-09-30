import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ExportOptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ExportOptionTile({
    super.key,
    required this.title,
    required this.selected,
    this.enabled = true,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return HoverButton(
      onPressed: enabled ? onTap : null,
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.all(12.0), // Padding ridotto
          decoration: BoxDecoration(
            color: _getBackgroundColor(theme, states),
            border: selected
                ? Border.all(color: theme.accentColor, width: 2.0)
                : null,
          ),
          child: Row(
            children: [
              RadioButton(
                checked: selected,
                onChanged: enabled ? (_) => onTap?.call() : null,
              ),
              const SizedBox(width: 12), // Spaziatura ridotta

              Expanded(
                child: Text(
                  title,
                  style: theme.typography.body?.copyWith( // Body invece di bodyLarge
                    color: enabled
                        ? (selected ? theme.accentColor : theme.typography.body?.color)
                        : theme.typography.body?.color?.withOpacity(0.5),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),

              if (trailing != null) ...[
                const SizedBox(width: 12), // Spaziatura ridotta
                trailing!,
              ],

              if (selected) ...[
                const SizedBox(width: 8), // Spaziatura ridotta
                Container(
                  padding: const EdgeInsets.all(4), // Padding ridotto
                  decoration: BoxDecoration(
                    color: theme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.check,
                    size: 10, // Icona più piccola
                    color: theme.accentColor,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(FluentThemeData theme, Set<ButtonStates> states) {
    if (!enabled) return theme.cardColor.withOpacity(0.5);
    if (states.isPressing) return theme.accentColor.withOpacity(0.1);
    if (states.isHovering) return theme.accentColor.withOpacity(0.05);
    if (selected) return theme.accentColor.withOpacity(0.03);
    return theme.cardColor;
  }
}

