import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginForm extends StatefulWidget {
  final void Function(String email, String password) onLogin;
  const LoginForm({super.key, required this.onLogin});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, // allinea a textfield
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Log in",
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Email
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: "Email address",
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),

        // Password
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: "Password",
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 32),

        // Bottone Login
        ElevatedButton(
          onPressed: () => widget.onLogin(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56), // stessa altezza textfield
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Log in", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),

        const SizedBox(height: 16),

        // Recupero password con context.go
        TextButton(
          onPressed: () => context.go('/recover'),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 56), // stessa altezza
            alignment: Alignment.center,
          ),
          child: const Text("Problemi con l'accesso?"),
        ),
      ],
    );
  }
}
