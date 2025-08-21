import 'package:flutter/material.dart';

class RegisterHeader extends StatelessWidget {
  final VoidCallback onGoToLogin;
  const RegisterHeader({super.key, required this.onGoToLogin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF60A5FA) : Theme.of(context).primaryColor;

    return Column(
      children: [
        const Text(
          'Register',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account? '),
            GestureDetector(
              onTap: onGoToLogin,
              child: Text(
                'Log in',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}