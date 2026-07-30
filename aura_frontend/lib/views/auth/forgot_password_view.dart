import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/theme.dart';
import 'package:aura_frontend/services/auth_service.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Please enter your email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordReset(email);
      _showSnackBar('Password reset email sent. Please check your inbox.', isSuccess: true);
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) context.pop();
        });
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AuraColors.present : AuraColors.absent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.background,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuraColors.primary.withOpacity(0.08),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32.0),
                decoration: AuraTheme.glassDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, size: 50, color: AuraColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'RESET PASSWORD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your registered email below to receive password recovery instructions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AuraColors.textMuted, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    
                    // Email Field
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
                    const SizedBox(height: 24),
                    
                    // Reset Button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: AuraColors.primary))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AuraColors.primary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _sendResetEmail,
                            child: const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                    const SizedBox(height: 20),
                    
                    // Cancel
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel & Go Back', style: TextStyle(color: AuraColors.textMuted, fontSize: 13)),
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
