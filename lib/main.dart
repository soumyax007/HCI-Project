import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/language_selection_screen.dart';
import 'screens/main_shell.dart';
import 'services/app_settings.dart';
import 'theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUPABASE CONFIG
// 1. Go to https://supabase.com → New project
// 2. Settings → API → copy Project URL and anon/public key
// 3. Replace the two placeholder strings below
// 4. Run the SQL from the README to create tables
// ─────────────────────────────────────────────────────────────────────────────
const _supabaseUrl  = 'https://opzhdqrogthmroqvlodo.supabase.co';  // e.g. https://xxxx.supabase.co
const _supabaseKey  = 'sb_publishable_gFV1kaHPjPJq3CX2zcvAWw_koH7fHvf';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseKey);

  // Load any previously saved session from shared_preferences
  await AppSettings.instance.loadFromPrefs();

  runApp(const MedHelpApp());
}

class MedHelpApp extends StatelessWidget {
  const MedHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    // If the user already completed sign-up in a previous session,
    // skip the onboarding flow and go straight to the main app.
    final home = AppSettings.instance.isLoggedIn
        ? const MainShell()
        : const LanguageSelectionScreen();

    return MaterialApp(
      title: 'MedHelp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: home,
    );
  }
}