import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.preferredLanguageCode});
  final String preferredLanguageCode;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey             = GlobalKey<FormState>();
  final _nameCtrl            = TextEditingController();
  final _emailCtrl           = TextEditingController();
  final _passwordCtrl        = TextEditingController();
  final _confirmPassCtrl     = TextEditingController();
  final _mobileCtrl          = TextEditingController();
  final _ageCtrl             = TextEditingController();
  final _contactNameCtrl     = TextEditingController();
  final _contactMobileCtrl   = TextEditingController();

  late String _selectedLanguageCode;
  bool _isLoading    = false;
  bool _obscurePass  = true;
  bool _obscureConf  = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = widget.preferredLanguageCode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    _confirmPassCtrl.dispose(); _mobileCtrl.dispose(); _ageCtrl.dispose();
    _contactNameCtrl.dispose(); _contactMobileCtrl.dispose();
    super.dispose();
  }



  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      // Step 1: Generate OTP and send via Resend (Commented out for now)
      /*
      final otp = (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
      await AuthService.instance.sendOtp(_emailCtrl.text.trim(), otp);
      if (!mounted) return;
      
      // Step 2: Show OTP Dialog
      final enteredOtp = await _showOtpDialog(otp);
      if (enteredOtp == null || enteredOtp != otp) {
        setState(() { _isLoading = false; _errorMsg = 'Invalid or canceled OTP.'; });
        return;
      }
      */

      await AuthService.instance.signUp(
        email:           _emailCtrl.text.trim(),
        password:        _passwordCtrl.text,
        name:            _nameCtrl.text.trim(),
        age:             '',
        mobile:          _mobileCtrl.text.trim(),
        languageCode:    _selectedLanguageCode,
        caregiverName:   _contactNameCtrl.text.trim(),
        caregiverMobile: _contactMobileCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── logo ───────────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/SVG/medi-care-logo.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Medi Care', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 24),
                const Center(
                  child: Text('Create Account',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600,
                          color: AppColors.sageDark,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.sageDark)),
                ),
                const SizedBox(height: 22),
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
                const FieldLabel('Full Name'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'Ramesh Kumar'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                const FieldLabel('Email Address'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'you@example.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email address';
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
                    hintText: 'Create a password',
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
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const FieldLabel('Confirm Password'),
                TextFormField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConf,
                  decoration: InputDecoration(
                    hintText: 'Re-enter your password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConf
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConf = !_obscureConf),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _passwordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                // ── Additional Fields ──────────────────────────────────────
                const SizedBox(height: 18),
                const FieldLabel('Mobile Number'),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '9876543210', counterText: ''),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null; // Optional? Or required? User said "if initially phone number or caregiver number or name not set so user can set it on the profile section". So it can be empty.
                    if (v.length != 10) return 'Enter exactly 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const FieldLabel('Caregiver Name'),
                TextFormField(
                  controller: _contactNameCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Son / Daughter Name'),
                ),
                const SizedBox(height: 18),
                const FieldLabel('Caregiver Mobile'),
                TextFormField(
                  controller: _contactMobileCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '9876543210', counterText: ''),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.length != 10) return 'Enter exactly 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white))
                        : const Text('Create Account'),
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
                    child: const Text('Back to language selection',
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