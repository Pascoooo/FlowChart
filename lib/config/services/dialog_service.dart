// lib/config/services/dialog_service.dart
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Un servizio di utilità per mostrare dialoghi modali standardizzati nell'app.
class DialogService {
  /// Mostra un dialogo informativo animato con sfondo sfocato.
  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        String? message,
        required IconData icon,
        Color? iconColor,
        String closeText = 'OK',
      }) async {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _StyledInfoDialog(
          title: title,
          message: message,
          icon: icon,
          iconColor: iconColor ?? Theme.of(context).colorScheme.primary,
          closeText: closeText,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  /// Mostra un dialogo di conferma in stile nativo (Cupertino).
  /// Restituisce `true` se l'utente conferma, `false` altrimenti.
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
      }) async {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Mostra un dialogo per l'inserimento di testo con validazione in tempo reale.
  static Future<String?> showInputDialog(
      BuildContext context, {
        required String title,
        String? message,
        String? initialValue,
        String hintText = '',
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        String? Function(String?)? validator,
      }) async {
    final controller = TextEditingController(text: initialValue);

    return showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? errorText;
            bool isButtonEnabled = false;

            void validate(String value) {
              if (validator != null) {
                errorText = validator(value);
                isButtonEnabled = errorText == null;
              } else {
                isButtonEnabled = value.trim().isNotEmpty;
              }
            }

            // Imposta lo stato iniziale
            validate(controller.text);

            return CupertinoAlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message != null) ...[
                    Text(message, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 16),
                  ],
                  CupertinoTextField(
                    controller: controller,
                    autofocus: true,
                    placeholder: hintText,
                    onChanged: (value) => setState(() => validate(value)),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorText!,
                        style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              actions: <CupertinoDialogAction>[
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(cancelText),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: isButtonEnabled
                      ? () => Navigator.of(context).pop(controller.text.trim())
                      : null,
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Mostra un dialogo di caricamento semplice senza freeze dell'UI
  static void showLoadingDialog(BuildContext context, {
    required String message,
    required bool barrierDismissible
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => PopScope(
        canPop: barrierDismissible,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mostra un dialogo di successo con animazione
  static Future<void> showSuccessDialog(
      BuildContext context, {
        required String title,
        String? message,
        String closeText = 'OK',
      }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AnimatedResultDialog(
        title: title,
        message: message,
        icon: Icons.check_circle,
        iconColor: Colors.green,
        closeText: closeText,
        isSuccess: true,
      ),
    );
  }

  /// Mostra un dialogo di errore con animazione
  static Future<void> showErrorDialog(
      BuildContext context, {
        required String title,
        String? message,
        String closeText = 'Chiudi',
      }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AnimatedResultDialog(
        title: title,
        message: message,
        icon: Icons.error,
        iconColor: Colors.red,
        closeText: closeText,
        isSuccess: false,
      ),
    );
  }
}

class _StyledInfoDialog extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Color iconColor;
  final String closeText;

  const _StyledInfoDialog({
    required this.title,
    this.message,
    required this.icon,
    required this.iconColor,
    required this.closeText,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350, minWidth: 280),
            child: Material(
              elevation: 24.0,
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: _AnimatedDialogContent(
                  title: title,
                  message: message,
                  icon: icon,
                  iconColor: iconColor,
                  closeText: closeText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedDialogContent extends StatefulWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Color iconColor;
  final String closeText;

  const _AnimatedDialogContent({
    required this.title,
    this.message,
    required this.icon,
    required this.iconColor,
    required this.closeText,
  });

  @override
  State<_AnimatedDialogContent> createState() => _AnimatedDialogContentState();
}

class _AnimatedDialogContentState extends State<_AnimatedDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _iconScale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _iconScale,
          child: Icon(widget.icon, size: 64, color: widget.iconColor),
        ),
        const SizedBox(height: 24),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.iconColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.closeText),
          ),
        ),
      ],
    );
  }
}

/// Widget per dialoghi animati di successo/errore
class _AnimatedResultDialog extends StatefulWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Color iconColor;
  final String closeText;
  final bool isSuccess;

  const _AnimatedResultDialog({
    required this.title,
    this.message,
    required this.icon,
    required this.iconColor,
    required this.closeText,
    required this.isSuccess,
  });

  @override
  State<_AnimatedResultDialog> createState() => _AnimatedResultDialogState();
}

class _AnimatedResultDialogState extends State<_AnimatedResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(
                  widget.icon,
                  size: 64,
                  color: widget.iconColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.closeText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}