import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SocialButtons extends StatelessWidget {
  final bool isGoogleLoading;
  final VoidCallback onGoogleLogin;
  final VoidCallback onEmailRegister;

  const SocialButtons({
    super.key,
    required this.isGoogleLoading,
    required this.onGoogleLogin,
    required this.onEmailRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: isGoogleLoading ? null : onGoogleLogin,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isGoogleLoading
              ? const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text("Accedi con Google"),
            ],
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FontAwesomeIcons.google, size: 20),
              SizedBox(width: 12),
              Text("Accedi con Google"),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onEmailRegister,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline, size: 20),
              SizedBox(width: 12),
              Text("Registrati con Email"),
            ],
          ),
        ),
      ],
    );
  }
}
