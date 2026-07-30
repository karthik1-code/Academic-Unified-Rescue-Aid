import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/services/auth_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({Key? key}) : super(key: key);

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('All fields are required.');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.registerWithEmail(email, password);
      if (credential != null && credential.user != null) {
        if (mounted) {
          // Go to onboarding directly to capture profile details
          context.go('/onboarding');
        }
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AuraColors.absent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.background,
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraColors.secondary.withOpacity(0.12),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(32.0),
                decoration: AuraTheme.glassDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => AuraColors.auroraGradient.createShader(bounds),
                          child: const Icon(Icons.blur_on, size: 36, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'REGISTER',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your AURA core identity',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AuraColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 32),
                    
                    // Email
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined, color: AuraColors.primary, size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.01),
                        labelStyle: const TextStyle(color: AuraColors.textMuted, fontSize: 13),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AuraColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Create Password',
                        prefixIcon: const Icon(Icons.lock_outlined, color: AuraColors.primary, size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.01),
                        labelStyle: const TextStyle(color: AuraColors.textMuted, fontSize: 13),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AuraColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    // Confirm Password
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_clock_outlined, color: AuraColors.primary, size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.01),
                        labelStyle: const TextStyle(color: AuraColors.textMuted, fontSize: 13),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AuraColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // Register button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AuraColors.primary))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AuraColors.secondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _register,
                            child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                    const SizedBox(height: 24),
                    
                    // Navigation to login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account? ", style: TextStyle(color: AuraColors.textMuted, fontSize: 12)),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Text(
                            'Log In',
                            style: TextStyle(color: AuraColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
