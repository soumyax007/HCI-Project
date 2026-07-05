import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class LanguageOption {
  final String nativeLabel;
  final String englishLabel;
  final String code;
  const LanguageOption(this.nativeLabel, this.englishLabel, this.code);
}

// Marathi (mr) and Punjabi (pa) removed.
const List<LanguageOption> kLanguages = [
  LanguageOption('English',  '',        'en'),
  LanguageOption('हिंदी',    'Hindi',   'hi'),
  LanguageOption('বাংলা',    'Bengali', 'bn'),
  LanguageOption('தமிழ்',    'Tamil',   'ta'),
  LanguageOption('తెలుగు',   'Telugu',  'te'),
];

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedCode;

  void _continue() {
    if (_selectedCode == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignUpScreen(preferredLanguageCode: _selectedCode!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedCode != null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.spa_outlined, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text('MedHelp', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Your trusted medication companion',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose your reading language',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('अपनी भाषा चुनें · আপনার ভাষা বেছে নিন',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
              const SizedBox(height: 18),
              ...kLanguages.map((lang) {
                final selected = _selectedCode == lang.code;
                return SelectableRow(
                  title: lang.nativeLabel,
                  trailing: lang.englishLabel.isEmpty ? null : lang.englishLabel,
                  selected: selected,
                  onTap: () => setState(() => _selectedCode = lang.code),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canContinue ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canContinue ? AppColors.sageDark : AppColors.sageMuted,
                  ),
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 16),
              // Already have an account? → Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Log in',
                        style: TextStyle(
                            color: AppColors.sageDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}