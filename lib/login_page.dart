import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              /// LEFT COLUMN: Login form
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Log in",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Email address",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Log in"),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {},
                      child: const Text("Can’t log in?"),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 40),

              /// RIGHT COLUMN: Social login
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Or continue with",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),
                    _socialButton(
                      icon: FontAwesomeIcons.google,
                      text: "Google",
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    _socialButton(
                      icon: FontAwesomeIcons.github,
                      text: "GitHub",
                      onPressed: () {},
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _socialButton(
                      icon: Icons.mail_outline,
                      text: "Sign up with Email",
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(text),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
