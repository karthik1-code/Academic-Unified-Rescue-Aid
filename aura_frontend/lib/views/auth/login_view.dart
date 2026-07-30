import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/providers/providers.dart';
import 'package:aura_frontend/services/auth_service.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithEmail(email, password);
      if (credential != null && credential.user != null) {
        final studentId = credential.user!.uid;
        final profile = await ref.read(authProvider.notifier).loadProfile(studentId);
        
        if (mounted) {
          if (profile != null) {
            context.go('/dashboard');
          } else {
            context.go('/onboarding');
          }
        }
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential != null && credential.user != null) {
        final studentId = credential.user!.uid;
        final profile = await ref.read(authProvider.notifier).loadProfile(studentId);
        
        if (mounted) {
          if (profile != null) {
            context.go('/dashboard');
          } else {
            context.go('/onboarding');
          }
        }
      } else {
        _showSnackBar("Google Sign-In was cancelled.");
      }
    } catch (e) {
      debugPrint("Google OAuth failed: $e");
      _showSnackBar("Google Sign-In failed: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isWarning ? AuraColors.primary : AuraColors.absent,
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
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraColors.accent.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraColors.primary.withOpacity(0.1),
              ),
            ),
          ),
          
          // Form Container
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
                    // Logo Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         ShaderMask(
                          shaderCallback: (bounds) => AuraColors.auroraGradient.createShader(bounds),
                          child: const Icon(Icons.psychology, size: 40, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AURA',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            foreground: Paint()
                              ..shader = AuraColors.auroraGradient.createShader(
                                const Rect.fromLTWH(0, 0, 200, 70),
                              ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Academic Unified Rescue Aid',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AuraColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 36),
                    
                    // Email Input
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
                    
                    // Password Input
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined, color: AuraColors.primary, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AuraColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
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
                    
                    // Forgot Password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: AuraColors.primary, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Login Button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AuraColors.primary))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AuraColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _loginWithEmail,
                            child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                    const SizedBox(height: 16),
                    
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text('OR', style: TextStyle(color: AuraColors.textMuted, fontSize: 11)),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Google OAuth Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _loginWithGoogle,
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                        height: 18,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 20),
                      ),
                      label: const Text('Continue with Google', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
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
