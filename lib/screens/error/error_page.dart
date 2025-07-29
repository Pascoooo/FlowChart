import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';

class ErrorPage extends StatelessWidget {
  final String? error;

  const ErrorPage({
    super.key,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Sfondo colorato per tutta la pagina - stesso stile login/register
      backgroundColor: isDark
          ? const Color(0xFF0F1419) // Blu scuro elegante per tema scuro
          : const Color(0xFFF8FAFC), // Grigio chiaro per tema chiaro

      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 800, // Larghezza massima del riquadro
              maxHeight: 600, // Altezza massima del riquadro
            ),
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.grey.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icona di errore con lo stesso stile del design
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.red[900]?.withOpacity(0.2)
                        : Colors.red[50],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.red[400]!.withOpacity(0.3)
                          : Colors.red[100]!,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: isDark
                        ? Colors.red[400]
                        : Colors.red[600],
                  ),
                ),

                const SizedBox(height: 32),

                // Titolo - stesso stile delle altre pagine
                const Text(
                  'Oops! Qualcosa è andato storto',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Descrizione
                Text(
                  'Si è verificato un errore imprevisto.\nNon preoccuparti, stiamo lavorando per risolverlo.',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Messaggio di errore (se presente) - stesso stile
                if (error != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      'Dettagli errore: $error',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Pulsanti - stesso stile delle altre pagine
                Row(
                  children: [
                    // Pulsante principale - Torna alla Home
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _goHome(context),
                        icon: const Icon(Icons.home, size: 20),
                        label: const Text(
                          'Torna alla Home',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Pulsante secondario - Riprova
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _retry(context),
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text(
                          'Riprova',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Separatore OR - stesso stile della pagina di registrazione
                _buildOrDivider(context),

                const SizedBox(height: 24),

                // Messaggio di supporto
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 16,
                      color: isDark
                          ? Colors.grey[500]
                          : Colors.grey[500],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Il problema persiste? Contatta il supporto',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey[500]
                            : Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: const Text(
            "ERRORE",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
      ],
    );
  }

  void _goHome(BuildContext context) {
    context.go('/');
  }

  void _retry(BuildContext context) {
    // Prova a ricaricare la pagina corrente o torna indietro
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}