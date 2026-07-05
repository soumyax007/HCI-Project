import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'language_selection_screen.dart';
import 'main_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.preferredLanguageCode});

  final String preferredLanguageCode;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _nameCtrl             = TextEditingController();
  final _ageCtrl              = TextEditingController();
  final _mobileCtrl           = TextEditingController();
  final _passwordCtrl         = TextEditingController();
  final _contactNameCtrl      = TextEditingController();
  final _contactMobileCtrl    = TextEditingController();

  late String _selectedLanguageCode;
  bool _isLoading     = false;
  bool _obscurePass   = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _selectedLanguageCode = widget.preferredLanguageCode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _ageCtrl.dispose(); _mobileCtrl.dispose();
    _passwordCtrl.dispose(); _contactNameCtrl.dispose(); _contactMobileCtrl.dispose();
    super.dispose();
  }

  String _labelFor(String code) {
    final match = kLanguages.firstWhere(
      (l) => l.code == code, orElse: () => kLanguages.first);
    return match.englishLabel.isEmpty ? match.nativeLabel : match.englishLabel;
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      await AuthService.instance.signUp(
        name:            _nameCtrl.text.trim(),
        age:             _ageCtrl.text.trim(),
        mobile:          _mobileCtrl.text.trim(),
        password:        _passwordCtrl.text,
        languageCode:    _selectedLanguageCode,
        caregiverName:   _contactNameCtrl.text.trim(),
        caregiverMobile: _contactMobileCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false, // removes LanguageSelectionScreen + SignUpScreen from stack
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
                // ── logo ─────────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.spa_outlined, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('MedHelp', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 24),
                const Center(
                  child: Text('Create Account',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: AppColors.sageDark,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.sageDark,
                    )),
                ),
                const SizedBox(height: 22),
                // ── error banner ──────────────────────────────────────
                if (_errorMsg != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_errorMsg!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                ],
                // ── fields ────────────────────────────────────────────
                const FieldLabel('Full Name'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'Ramesh Kumar'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                const FieldLabel('Age'),
                TextFormField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '68'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                const FieldLabel('Preferred Language'),
                DropdownButtonFormField<String>(
                  value: _selectedLanguageCode,
                  decoration: const InputDecoration(),
                  items: kLanguages.map((l) => DropdownMenuItem(
                    value: l.code,
                    child: Text(_labelFor(l.code)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedLanguageCode = v ?? _selectedLanguageCode),
                ),
                const SizedBox(height: 18),
                const FieldLabel('Mobile Number'),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '98765 43210'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                const FieldLabel('Password'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    hintText: 'Create a password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textMuted),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                // ── emergency contact card ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(text: const TextSpan(
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
                        children: [
                          TextSpan(text: 'Family emergency contact '),
                          TextSpan(text: '(optional)',
                            style: TextStyle(fontWeight: FontWeight.w400, color: AppColors.textMuted)),
                        ],
                      )),
                      const SizedBox(height: 4),
                      const Text('Used for SOS calls and missed-dose alerts',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _contactNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Contact name (e.g. Priya — daughter)',
                          filled: true, fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactMobileCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '+91 mobile number',
                          filled: true, fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 12),
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