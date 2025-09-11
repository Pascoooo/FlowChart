import 'package:flutter/material.dart';

class ErrorBanner extends StatefulWidget {
  final String message;
  final VoidCallback onClose;

  const ErrorBanner({
    super.key,
    required this.message,
    required this.onClose,
  });

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() {
    _controller.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          // Rimosso il margine orizzontale per un controllo migliore nella pagina genitore
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16), // Aumentato per un look più moderno
            border: Border.all(
              color: theme.colorScheme.error.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.error.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded, // Icona arrotondata
                color: theme.colorScheme.onErrorContainer,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _handleClose, // Usa il nuovo metodo per l'animazione di uscita
                icon: Icon(
                  Icons.close_rounded, // Icona arrotondata
                  color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
                  size: 20,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}