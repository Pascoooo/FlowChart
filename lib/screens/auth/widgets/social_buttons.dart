/// Bottone animato per l'autenticazione social.
/// Gestisce stati di loading, pressione e shimmer per call-to-action primaria.
/// Ottimizzato per Flutter web con feedback chiari e disabilitazioni sicure.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialAuthButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? iconColor;
  final bool isPrimary;
  final bool isEnabled;

  const SocialAuthButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.iconColor,
    this.isPrimary = false,
    this.isEnabled = true,
  });

  @override
  State<SocialAuthButton> createState() => _SocialAuthButtonState();
}

class _SocialAuthButtonState extends State<SocialAuthButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isPressed = false;

  /// Avvia i controller e setup animazioni per scale/shimmer del bottone.
  /// Richiamato una sola volta per prevenire stutter nelle animazioni.
  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  /// Configura tween e loop animati per shimmer e pressione.
  /// Se il bottone è primario avvia lo shimmer by default.
  void _initAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    if (widget.isPrimary && !widget.isLoading) {
      _shimmerController.repeat();
    }
  }

  /// Aggiorna gli stati animati quando cambiano le proprietà widget.
  /// Ferma o riavvia lo shimmer in base a loading e flag primario.
  @override
  void didUpdateWidget(SocialAuthButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPrimary &&
        !widget.isLoading &&
        !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if ((!widget.isPrimary || widget.isLoading) &&
        _shimmerController.isAnimating) {
      _shimmerController.stop();
      _shimmerController.reset();
    }
  }

  /// Rilascia le risorse dei controller per evitare leak.
  /// Chiamato quando il widget esce dall'albero.
  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  /// Gestisce il press iniziale abbassando la scala se cliccabile.
  /// Evita input quando in loading o disabilitato.
  void _onPointerDown(PointerDownEvent event) {
    if (widget.isEnabled && !widget.isLoading) {
      setState(() => _isPressed = true);
      _scaleController.forward();
    }
  }

  /// Rilascia il press e invoca onPressed dopo l'animazione di ritorno.
  /// Protegge da tap multipli durante fasi di loading.
  void _onPointerUp(PointerUpEvent event) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _scaleController.reverse().then((_) {
        if (widget.isEnabled && !widget.isLoading) {
          widget.onPressed();
        }
      });
    }
  }

  /// Ripristina lo stato premuto quando il puntatore viene annullato.
  /// Mantiene coerenza visiva in caso di drag fuori area.
  void _onPointerCancel(PointerCancelEvent event) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _scaleController.reverse();
    }
  }


  /// Costruisce il bottone con animazione di scala e gesture listener.
  /// Usa stack per shimmer opzionale e centra contenuto dinamico.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: widget.isPrimary
                    ? LinearGradient(
                  colors: [
                    theme.accentColor.dark,
                    theme.accentColor,
                  ],
                )
                    : null,
                color: widget.isPrimary
                    ? null
                    : (isDark
                    ? theme.cardColor.withOpacity(0.5)
                    : theme.cardColor),
                borderRadius: BorderRadius.circular(18),
                border: widget.isPrimary
                    ? null
                    : Border.all(
                  color: _isPressed
                      ? theme.accentColor.withOpacity(0.5)
                      : theme.inactiveColor.withOpacity(0.2),
                  width: _isPressed ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isPrimary
                        ? theme.accentColor
                        .withOpacity(_isPressed ? 0.4 : 0.3)
                        : Colors.black.withOpacity(_isPressed ? 0.08 : 0.05),
                    blurRadius:
                    widget.isPrimary ? (_isPressed ? 25 : 20) : (_isPressed ? 15 : 12),
                    offset: Offset(
                        0, widget.isPrimary ? (_isPressed ? 6 : 8) : (_isPressed ? 2 : 4)),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (widget.isPrimary && !widget.isLoading)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shimmerAnimation.value * 100, 0),
                              child: Container(
                                width: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.2),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildContent(theme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Rende il contenuto interno: spinner in loading o icona+testo standard.
  /// Adatta colori al tema corrente e stato primario/disabled.
  Widget _buildContent(FluentThemeData theme) {
    if (widget.isLoading) {
      final textColor =
      widget.isPrimary ? Colors.white : theme.typography.body?.color;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: ProgressRing(
              strokeWidth: 2.5,
              // ===== FIX: Ripristinato il colore originale per essere uguale a Material =====
              activeColor: widget.isPrimary ? Colors.white : theme.accentColor,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Accesso in corso...',
            style: theme.typography.bodyStrong?.copyWith(color: textColor),
          ),
        ],
      );
    }

    // Contenuto normale del bottone
    final textColor =
    widget.isPrimary ? Colors.white : theme.typography.body?.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaIcon(
          widget.icon,
          size: 22,
          color: widget.iconColor ??
              (widget.isPrimary ? Colors.white : theme.accentColor),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            widget.text,
            style: theme.typography.bodyStrong?.copyWith(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
