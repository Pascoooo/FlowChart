// lib/screens/user_dashboard/widgets/topbar_buttons.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import 'dart:js' as js;

class TopbarButtons extends StatelessWidget {
  final FileSystemLoaded state;

  const TopbarButtons({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelectedFile = state.activeFileId != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Basic project actions (always available when there are files)
        _TopBarButton(
          icon: FontAwesomeIcons.folderOpen,
          tooltip: "Proprietà progetto",
          onPressed: () => _onProjectProperties(context),
          theme: theme,
        ),

        const SizedBox(width: 8),

        // File-specific actions (only when file is selected)
        if (hasSelectedFile) ...[
          _TopBarButton(
            icon: FontAwesomeIcons.penToSquare,
            tooltip: "Modifica",
            onPressed: () => _onEdit(context),
            theme: theme,
            isPrimary: true,
          ),

          const SizedBox(width: 8),

          _TopBarButton(
            icon: FontAwesomeIcons.download,
            tooltip: "Esporta",
            onPressed: () => _onExport(context),
            theme: theme,
          ),

          const SizedBox(width: 8),

          _TopBarButton(
            icon: FontAwesomeIcons.share,
            tooltip: "Condividi",
            onPressed: () => _onShare(context),
            theme: theme,
          ),

          const SizedBox(width: 16),

          // Divider
          Container(
            width: 1,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  theme.colorScheme.outline.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          _TopBarButton(
            icon: FontAwesomeIcons.ellipsisVertical,
            tooltip: "Altre azioni",
            onPressed: () => _onMoreActions(context),
            theme: theme,
          ),
        ] else ...[
          // When no file is selected, show a hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  "Seleziona un file per vedere più opzioni",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _onProjectProperties(BuildContext context) {
    // Implementa logica per proprietà progetto
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Proprietà progetto - Da implementare")),
    );
  }

  void _onEdit(BuildContext context) {
    final baseUrl = Uri.base.toString().split('#')[0];
    js.context.callMethod('open', [
      '$baseUrl#/drawing-editor',
      '_blank',
      'width=1200,height=800,left=100,top=100,resizable=yes,scrollbars=yes,status=yes'
    ]);
  }

  void _onExport(BuildContext context) {
    // Implementa logica per esportazione
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Esporta file - Da implementare")),
    );
  }

  void _onShare(BuildContext context) {
    // Implementa logica per condivisione
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Condividi file - Da implementare")),
    );
  }

  void _onMoreActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MoreActionsSheet(state: state),
    );
  }
}

class _TopBarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final ThemeData theme;
  final bool isPrimary;

  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.theme,
    this.isPrimary = false,
  });

  @override
  State<_TopBarButton> createState() => _TopBarButtonState();
}

class _TopBarButtonState extends State<_TopBarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Tooltip(
            message: widget.tooltip,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                onTapDown: (_) => _scaleController.forward(),
                onTapUp: (_) {
                  _scaleController.reverse();
                  widget.onPressed();
                },
                onTapCancel: () => _scaleController.reverse(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: widget.isPrimary
                        ? LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : _isHovered
                        ? LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.1),
                        colorScheme.primary.withOpacity(0.05),
                      ],
                    )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: widget.isPrimary
                        ? [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: FaIcon(
                    widget.icon,
                    size: 16,
                    color: widget.isPrimary
                        ? colorScheme.onPrimary
                        : _isHovered
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoreActionsSheet extends StatelessWidget {
  final FileSystemLoaded state;

  const _MoreActionsSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _MoreActionItem(
                  icon: FontAwesomeIcons.copy,
                  title: "Duplica file",
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Duplica file - Da implementare")),
                    );
                  },
                ),

                _MoreActionItem(
                  icon: FontAwesomeIcons.clock,
                  title: "Cronologia versioni",
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Cronologia - Da implementare")),
                    );
                  },
                ),

                _MoreActionItem(
                  icon: FontAwesomeIcons.tags,
                  title: "Rinomina",
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Rinomina - Da implementare")),
                    );
                  },
                ),

                const Divider(),

                _MoreActionItem(
                  icon: FontAwesomeIcons.trash,
                  title: "Elimina",
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Elimina - Da implementare")),
                    );
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _MoreActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MoreActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return ListTile(
      leading: FaIcon(
        icon,
        size: 18,
        color: color.withOpacity(0.7),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}