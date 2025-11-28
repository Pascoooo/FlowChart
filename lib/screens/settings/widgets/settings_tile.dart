/// Tile riutilizzabile per voci di impostazione con icona, titolo, sottotitolo e trailing.
/// Supporta stati distruttivi, hover e trailing custom o indicatore di navigazione.

import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final bool isDestructive;

  const SettingsTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
    this.isDestructive = false,
  });

  /// Costruisce il tile impostazioni con feedback visivo e gestione del trailing.
  /// Include colori specifici per azioni distruttive e il caret di default quando onTap è presente.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final destructiveColor = theme.resources.systemFillColorCritical;
    final finalIconColor =
        isDestructive ? destructiveColor : (iconColor ?? theme.accentColor);
    final finalTitleColor = isDestructive ? destructiveColor : titleColor;

    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.all(12.0), // Padding ridotto
          decoration: BoxDecoration(
            color: _getBackgroundColor(theme, states, isDestructive),
          ),
          child: Row(
            children: [
              _buildIconContainer(context, finalIconColor, states),
              const SizedBox(width: 12), // Spaziatura ridotta

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titolo su una riga con ellissi
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body?.copyWith( // Typography ridotta
                        color: finalTitleColor ?? theme.typography.body?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2), // Spazio ridotto
                    // Sottotitolo su una riga con ellissi
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption?.copyWith( // Caption invece di body
                        color: theme.typography.caption?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6), // Padding ridotto
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(
                        alpha: states.isHovered ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 12, // Icona più piccola
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Disegna il contenitore dell'icona applicando hover border e dimensioni ridotte.
  /// Restituisce un widget pronto per essere inserito nella row principale.
  Widget _buildIconContainer(
      BuildContext context, Color iconColor, Set<WidgetState> states) {
    return Container(
      width: 40, // Dimensione ridotta
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: states.isHovered ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10), // Bordi più piccoli
        border: states.isHovered
            ? Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.0)
            : null,
      ),
      child: Center(
        child: FaIcon(
          icon,
          color: iconColor,
          size: 18, // Icona più piccola
        ),
      ),
    );
  }

  /// Determina il colore di background del tile in base allo stato e al flag distruttivo.
  /// Rende più evidente l'azione su hover/press e mantiene lo sfondo neutro altrimenti.
  Color _getBackgroundColor(
      FluentThemeData theme, Set<WidgetState> states, bool isDestructive) {
    if (isDestructive) {
      final destructiveColor = theme.resources.systemFillColorCritical;
      if (states.isPressed) return destructiveColor.withValues(alpha: 0.1);
      if (states.isHovered) return destructiveColor.withValues(alpha: 0.05);
      return theme.cardColor;
    }

    if (states.isPressed) return theme.accentColor.withValues(alpha: 0.1);
    if (states.isHovered) return theme.accentColor.withValues(alpha: 0.05);
    return theme.cardColor;
  }
}
