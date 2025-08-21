import 'package:flowchart_thesis/screens/auth/logic/register_functions.dart';
import 'package:flowchart_thesis/screens/auth/widgets/step_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import '../widgets/register_header.dart';
import '../widgets/register_step_email.dart';
import '../widgets/register_step_info.dart';
import '../widgets/register_step_password.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _controller = RegisterFunctions();

  int _currentStep = 0;
  final PageController _pageController = PageController();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final List<String> _stepTitles = const [
    "Enter your email address",
    "Provide your basic info",
    "Create your password"
  ];

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                RegisterHeader(onGoToLogin: () => context.go('/login')),
                const SizedBox(height: 24),
                StepProgressIndicator(
                  totalSteps: 3,
                  currentStep: _currentStep,
                  titles: _stepTitles,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      RegisterStepEmail(
                        emailController: _emailController,
                        onNext: _handleNextFromEmail,
                      ),
                      RegisterStepInfo(
                        firstNameController: _firstNameController,
                        lastNameController: _lastNameController,
                        onBack: _previousStep,
                        onNext: _handleNextFromInfo,
                      ),
                      RegisterStepPassword(
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmPasswordController,
                        obscurePassword: _obscurePassword,
                        obscureConfirmPassword: _obscureConfirmPassword,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                        onToggleConfirmPassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        isLoading: _isLoading,
                        onBack: _previousStep,
                        onSubmit: _handleCreateAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNextFromEmail() {
    final ok = _controller.validateEmail(context, _emailController.text.trim());
    if (ok) _nextStep();
  }

  void _handleNextFromInfo() {
    final ok = _controller.validateNames(
      context,
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    );
    if (ok) _nextStep();
  }

  Future<void> _handleCreateAccount() async {
    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (!_controller.validatePasswords(context, password, confirm)) return;

    setState(() => _isLoading = true);
    try {
      await _controller.signUp(context, email, firstName, lastName, password);
      if (!mounted) return;
      context.replace('/home');
    } catch (e) {
      if (!mounted) return;
      _controller.showSnackBar(context, 'Errore durante la registrazione: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
}