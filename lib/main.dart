import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/language_selection_screen.dart';
import 'screens/main_shell.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/app_settings.dart';
import 'services/notification_service.dart';
import 'services/reminder_store.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // ignore: deprecated_member_use
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!, 
  );

  // 2. Restore previous session from SharedPreferences
  await AppSettings.instance.loadFromPrefs();

  // 3. Initialise notification service (requests permissions, sets up channels)
  await NotificationService.instance.init();

  // 4. Load reminders (from Supabase if logged in, else local cache)
  await ReminderStore.instance.load();

  runApp(const MedHelpApp());
}

class MedHelpApp extends StatelessWidget {
  const MedHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Skip onboarding if user already has a valid session.
    final home = AppSettings.instance.isLoggedIn
        ? const MainShell()
        : const LanguageSelectionScreen();

    return MaterialApp(
      title: 'Medi Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: home,
    );
  }
}