import 'package:flowchart_thesis/main.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
      // Sfondo colorato per tutta la pagina
      backgroundColor: isDark
          ? const Color(0xFF0F1419) // Blu scuro elegante per tema scuro
          : const Color(0xFFF8FAFC), // Grigio chiaro per tema chiaro

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 600, // Più stretto rispetto al login
              ),
              margin: const EdgeInsets.all(20), // Ridotto il margine
              padding: const EdgeInsets.all(32), // Ridotto il padding
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
              child: _emailSent ? _buildEmailSentView() : _buildFormView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      mainAxisSize: MainAxisSize.min, // Importante: usa min invece di max
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icona e titolo
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.lock_reset,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20), // Ridotto da 24
              const Text(
                "Recupera Password",
                style: TextStyle(
                  fontSize: 28, // Ridotto da 32
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12), // Ridotto da 16

        // Testo descrittivo
        Center(
          child: Text(
            "Inserisci l'indirizzo email associato al tuo account\ne ti invieremo un link per reimpostare la password.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14, // Ridotto da 16
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              height: 1.4, // Ridotto da 1.5
            ),
          ),
        ),
        const SizedBox(height: 32), // Ridotto da 40

        // Campo email
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: "Indirizzo email",
            hintText: "inserisci@esempio.it",
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
        ),
        const SizedBox(height: 24), // Ridotto da 32

        // Pulsante invio
        ElevatedButton(
          onPressed: _isLoading ? null : _sendResetEmail,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text(
            "Invia Link di Recupero",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 20), // Ridotto da 24

        // Link di ritorno al login
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Ricordi la password? ",
                style: TextStyle(
                  fontSize: 14, // Specificato esplicitamente
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/login');
                },
                child: const Text(
                  "Torna al Login",
                  style: TextStyle(
                    fontSize: 14, // Specificato esplicitamente
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSentView() {
    return Column(
      mainAxisSize: MainAxisSize.min, // Importante: usa min invece di max
      children: [
        // Icona di successo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 50, // Ridotto da 60
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24), // Ridotto da 32

        // Titolo
        const Text(
          "Email Inviata!",
          style: TextStyle(
            fontSize: 24, // Ridotto da 28
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12), // Ridotto da 16

        // Messaggio
        Text(
          "Abbiamo inviato un link per il recupero della password a:",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14, // Ridotto da 16
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _emailController.text,
            style: TextStyle(
              fontSize: 14, // Ridotto da 16
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16), // Ridotto da 24

        Text(
          "Controlla la tua casella di posta e segui le istruzioni\nper reimpostare la password.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13, // Ridotto da 14
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            height: 1.4, // Ridotto da 1.5
          ),
        ),
        const SizedBox(height: 32), // Ridotto da 40

        // Pulsanti di azione
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _emailSent = false;
                    _emailController.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Riprova"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  context.go('/login');
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Torna al Login"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _sendResetEmail() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar("Inserisci un indirizzo email valido");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simula l'invio dell'email (sostituisci con la logica reale)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
      _emailSent = true;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}