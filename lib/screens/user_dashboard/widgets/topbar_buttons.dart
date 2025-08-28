import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import 'dart:js' as js;

class TopbarButtons extends StatelessWidget {
  final FileSystemLoaded state;
  final VoidCallback onBackToProjects;

  const TopbarButtons({
    super.key,
    required this.state,
    required this.onBackToProjects,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelectedFile = state.activeFileId != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          tooltip: "Torna ai Progetti",
          onPressed: onBackToProjects,
        ),
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
        ],
      ],
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
