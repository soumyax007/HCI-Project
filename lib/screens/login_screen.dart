import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

/// Email + password login screen.
/// Reached via "Already have an account? Log in" on LanguageSelectionScreen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading   = false;
  bool _obscurePass = true;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      await AuthService.instance.signIn(
        emailOrPhone: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _errorMsg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('AuthException: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _errorMsg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('AuthException: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailOrPhone = _emailCtrl.text.trim();
    if (emailOrPhone.isEmpty || !emailOrPhone.contains('@')) {
      setState(() => _errorMsg = 'Enter a valid email to reset password.');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      await AuthService.instance.resetPassword(emailOrPhone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      setState(() => _errorMsg = e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('AuthException: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── logo ───────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.sage,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/SVG/medi-care-logo.svg',
                            width: 44,
                            height: 44,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Medi Care',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      const Text('Welcome back',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                // ── error banner ────────────────────────────────────────
                if (_errorMsg != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13)),
                  ),
                ],
                // ── fields ─────────────────────────────────────────────
                const FieldLabel('Email or Phone Number'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(hintText: 'you@example.com or +1234567890'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final val = v.trim();
                    if (!val.contains('@') && RegExp(r'^\d+$').hasMatch(val)) {
                      if (val.length != 10) return 'Enter exactly 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const FieldLabel('Password'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text('Forgot Password?', style: TextStyle(color: AppColors.sageDark, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white))
                        : const Text('Log In'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _googleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Sign in with Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      minimumSize: const Size.fromHeight(56),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}