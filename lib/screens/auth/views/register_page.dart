import 'package:flowchart_thesis/screens/auth/views/login_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _stepTitles = [
    "Enter your email address",
    "Provide your basic info",
    "Create your password"
  ];

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
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 800, // Larghezza massima del riquadro
              maxHeight: 750, // Aumentata l'altezza massima
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
            child: Column(
              children: [
                // Titolo principale
                const Text(
                  "Register",
                  style: TextStyle(
                    fontSize: 32, // Ridotto da 36
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12), // Ridotto da 16
                // Link al login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () {
                        context.go('/login');
                      },
                      child: Text(
                        "Log in",
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF60A5FA) // Blu chiaro per dark mode
                              : Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: isDark
                              ? const Color(0xFF60A5FA)
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24), // Ridotto da 32
                // Indicatore di progresso
                _buildProgressIndicator(),
                const SizedBox(height: 24), // Ridotto da 32
                // Contenuto dei passi
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                    ],
                  ),
                ),
                const SizedBox(height: 20), // Ridotto da 32
                // Separatore OR
                _buildOrDivider(),
                const SizedBox(height: 20), // Ridotto da 32
                // Pulsanti social
                _buildSocialButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        // Linea con punti numerati
        Row(
          children: [
            // Step 1
            _buildStepCircle(1, 0),
            // Linea di connessione 1-2
            _buildConnectorLine(0),
            // Step 2
            _buildStepCircle(2, 1),
            // Linea di connessione 2-3
            _buildConnectorLine(1),
            // Step 3
            _buildStepCircle(3, 2),
          ],
        ),
        const SizedBox(height: 16), // Ridotto da 20
        // Titoli degli step
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Text(
                _stepTitles[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, // Ridotto da 12
                  fontWeight: index == _currentStep
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: index <= _currentStep
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }


  Widget _buildStepCircle(int stepNumber, int stepIndex) {
    final isCurrent = stepIndex == _currentStep;
    final isCompleted = stepIndex < _currentStep;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color circleColor;
    Color textColor;

    if (isCompleted) {
      // Step completato - usa colore accent visibile
      circleColor = isDark ? const Color(0xFF06BEE1) : const Color(0xFF06BEE1);
      textColor = Colors.white;
    } else if (isCurrent) {
      // Step corrente - usa colore primario
      circleColor = isDark ? const Color(0xFF06BEE1) : Theme.of(context).primaryColor;
      textColor = Colors.white;
    } else {
      // Step futuro - usa grigio
      circleColor = isDark ? const Color(0xFF2D3748) : Colors.grey[300]!;
      textColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey[600]!;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: circleColor,
        border: isCurrent
            ? Border.all(
          color: isDark ? const Color(0xFF38BDF8) : Theme.of(context).primaryColor,
          width: 2,
        )
            : null,
        boxShadow: (isCurrent || isCompleted) ? [
          BoxShadow(
            color: (isDark ? const Color(0xFF06BEE1) : Theme.of(context).primaryColor).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Center(
        child: isCompleted
            ? const Icon(
          Icons.check,
          color: Colors.white,
          size: 18,
        )
            : Text(
          stepNumber.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorLine(int lineIndex) {
    final isActive = lineIndex < _currentStep;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF06BEE1) : Theme.of(context).primaryColor)
              : (isDark ? const Color(0xFF374151) : Colors.grey[300]),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
  Widget _buildStep1() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: "Email address",
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _nextStep(),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "Next",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: "First Name",
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: "Last Name",
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _previousStep(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _nextStep(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Next",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: "Confirm Password",
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _previousStep(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _completeRegistration(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Create Account",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: const Text(
              "OR",
              style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildSocialButtons() {
    return Column(
      children: [
        _socialButton(
          icon: FontAwesomeIcons.google,
          text: "Register with Google",
          onPressed: () {},
        ),
        const SizedBox(height: 16),
        _socialButton(
          icon: FontAwesomeIcons.github,
          text: "Register with GitHub",
          onPressed: () {},
        ),
      ],
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
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeRegistration() {
    // Implementa qui la logica di registrazione
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registration completed!")),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}