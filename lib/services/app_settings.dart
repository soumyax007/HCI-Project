import 'package:shared_preferences/shared_preferences.dart';

/// App-wide singleton that holds the current user's data in memory and
/// persists it to shared_preferences so the app survives restarts.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // ── in-memory state ──────────────────────────────────────────────────────
  String userId          = '';
  String name            = '';
  String age             = '';
  String mobile          = '';
  String languageCode    = 'en';
  String caregiverName   = '';
  String caregiverMobile = '';
  bool   isLoggedIn      = false;

  // ── persistence keys ─────────────────────────────────────────────────────
  static const _kUserId          = 'user_id';
  static const _kName            = 'name';
  static const _kAge             = 'age';
  static const _kMobile          = 'mobile';
  static const _kLanguage        = 'language_code';
  static const _kCaregiverName   = 'caregiver_name';
  static const _kCaregiverMobile = 'caregiver_mobile';
  static const _kIsLoggedIn      = 'is_logged_in';

  Future<void> loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    userId          = p.getString(_kUserId)          ?? '';
    name            = p.getString(_kName)            ?? '';
    age             = p.getString(_kAge)             ?? '';
    mobile          = p.getString(_kMobile)          ?? '';
    languageCode    = p.getString(_kLanguage)        ?? 'en';
    caregiverName   = p.getString(_kCaregiverName)   ?? '';
    caregiverMobile = p.getString(_kCaregiverMobile) ?? '';
    isLoggedIn      = p.getBool(_kIsLoggedIn)        ?? false;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserId,          userId);
    await p.setString(_kName,            name);
    await p.setString(_kAge,             age);
    await p.setString(_kMobile,          mobile);
    await p.setString(_kLanguage,        languageCode);
    await p.setString(_kCaregiverName,   caregiverName);
    await p.setString(_kCaregiverMobile, caregiverMobile);
    await p.setBool(_kIsLoggedIn,        isLoggedIn);
  }

  Future<void> clear() async {
    userId = name = age = mobile = '';
    languageCode = 'en';
    caregiverName = caregiverMobile = '';
    isLoggedIn = false;
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}