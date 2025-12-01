import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flowchart_thesis/config/router/app_router.dart';

// Enum per definire il tipo di banner
enum BannerType { error, success, info }

class BannerService {
  // Costruttore privato per impedire l'istanziazione
  BannerService._();

  /// Mostra un banner di errore.
  static void showError(BuildContext context, String message, {Duration? duration}) {
    _show(message: message, type: BannerType.error, duration: duration);
  }

  /// Mostra un banner di successo.
  static void showSuccess(BuildContext context, String message, {Duration? duration}) {
    _show(message: message, type: BannerType.success, duration: duration);
  }

  /// Mostra un banner informativo.
  static void showInfo(BuildContext context, String message, {Duration? duration}) {
    _show(message: message, type: BannerType.info, duration: duration);
  }

  /// Metodo privato per creare e mostrare l'overlay del banner.
  static void _show({
    required String message,
    required BannerType type,
    Duration? duration,
  }) {
    // Recupera l'Overlay dallo stato del root navigator per evitare lookup sul context chiamante.
    final overlayState = AppRouter.rootNavigatorKey.currentState?.overlay;
    if (overlayState == null) {
      // Se per qualche motivo il root navigator non è pronto, esci silenziosamente.
      return;
    }
    OverlayEntry? overlayEntry;

    void onRemove() {
      overlayEntry?.remove();
    }

    overlayEntry = OverlayEntry(
      builder: (context) {
        // Usiamo Positioned per posizionare il banner in alto.
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: _AnimatedBanner(
            message: message,
            type: type,
            onClose: onRemove,
            duration: duration,
          ),
        );
      },
    );

    // Inseriamo il nostro banner nell'overlay.
    overlayState.insert(overlayEntry);
  }
}

/// Il widget interno che gestisce l'animazione e l'aspetto del banner.
class _AnimatedBanner extends StatefulWidget {
  final String message;
  final BannerType type;
  final VoidCallback onClose;
  final Duration? duration;

  const _AnimatedBanner({
    required this.message,
    required this.type,
    required this.onClose,
    this.duration,
  });

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    // Aggiungiamo un listener per rimuovere il widget quando l'animazione di uscita è completa.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onClose();
      }
    });

    // Avviamo l'animazione di entrata.
    _controller.forward();

    // Impostiamo un timer per la chiusura automatica.
    _dismissTimer = Timer(widget.duration ?? _getDurationForType(), _close);
  }

  @override
  void dispose() {
    _controller.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  // Metodo per avviare l'animazione di uscita.
  void _close() {
    _dismissTimer?.cancel();
    if (mounted) _controller.reverse();
  }

  // Funzioni helper per ottenere stile e durata in base al tipo
  Color _getColorForType(BuildContext context) {
    switch (widget.type) {
      case BannerType.error:
        return Theme.of(context).colorScheme.errorContainer;
      case BannerType.success:
        return Colors.green.shade100; // Esempio
      case BannerType.info:
        return Theme.of(context).colorScheme.surfaceContainerHigh;
    }
  }

  Color _getOnColorForType(BuildContext context) {
    switch (widget.type) {
      case BannerType.error:
        return Theme.of(context).colorScheme.onErrorContainer;
      case BannerType.success:
        return Colors.green.shade900; // Esempio
      case BannerType.info:
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  IconData _getIconForType() {
    switch (widget.type) {
      case BannerType.error:
        return Icons.error_outline_rounded;
      case BannerType.success:
        return Icons.check_circle_outline_rounded;
      case BannerType.info:
        return Icons.info_outline_rounded;
    }
  }

  Duration _getDurationForType() {
    switch (widget.type) {
      case BannerType.error:
        return const Duration(seconds: 5);
      case BannerType.success:
      case BannerType.info:
        return const Duration(seconds: 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColorForType(context);
    final onColor = _getOnColorForType(context);
    final icon = _getIconForType();

    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: onColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: onColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _close,
                  icon: Icon(Icons.close_rounded, color: onColor.withOpacity(0.7), size: 20),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}