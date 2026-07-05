import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_settings.dart';

/// Wraps Supabase auth + profile table operations.
///
/// Auth strategy: we use email/password where the email is derived from
/// the mobile number as  {mobile}@medhelp.in  so the patient never has to
/// type an email address — they only ever see "mobile number" and "password".
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Converts a mobile number to a fake email for Supabase auth.
  String _toEmail(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    return '$digits@medhelp.in';
  }

  // ── sign up ───────────────────────────────────────────────────────────────

  /// Creates a Supabase auth account, inserts a profile row, and saves
  /// everything to [AppSettings] + shared_preferences.
  ///
  /// Throws a [String] error message on failure.
  Future<void> signUp({
    required String name,
    required String age,
    required String mobile,
    required String password,
    required String languageCode,
    String caregiverName   = '',
    String caregiverMobile = '',
  }) async {
    final email = _toEmail(mobile);

    // 1. Create auth account
    final res = await _db.auth.signUp(
      email: email,
      password: password,
    );

    final uid = res.user?.id;
    if (uid == null) throw 'Sign up failed — please try again.';

    // 2. Insert profile row
    await _db.from('profiles').insert({
      'id':               uid,
      'name':             name,
      'age':              int.tryParse(age) ?? 0,
      'mobile':           mobile,
      'preferred_language': languageCode,
      'caregiver_name':   caregiverName,
      'caregiver_mobile': caregiverMobile,
    });

    // 3. Persist to AppSettings
    final s = AppSettings.instance;
    s.userId          = uid;
    s.name            = name;
    s.age             = age;
    s.mobile          = mobile;
    s.languageCode    = languageCode;
    s.caregiverName   = caregiverName;
    s.caregiverMobile = caregiverMobile;
    s.isLoggedIn      = true;
    await s.save();
  }

  // ── sign in ───────────────────────────────────────────────────────────────

  /// Signs in with mobile + password and loads profile into [AppSettings].
  Future<void> signIn({
    required String mobile,
    required String password,
  }) async {
    final email = _toEmail(mobile);

    final res = await _db.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final uid = res.user?.id;
    if (uid == null) throw 'Login failed — check your mobile number and password.';

    // Load profile from DB
    final row = await _db
        .from('profiles')
        .select()
        .eq('id', uid)
        .single();

    final s = AppSettings.instance;
    s.userId          = uid;
    s.name            = row['name'] as String? ?? '';
    s.age             = row['age']?.toString() ?? '';
    s.mobile          = row['mobile'] as String? ?? '';
    s.languageCode    = row['preferred_language'] as String? ?? 'en';
    s.caregiverName   = row['caregiver_name'] as String? ?? '';
    s.caregiverMobile = row['caregiver_mobile'] as String? ?? '';
    s.isLoggedIn      = true;
    await s.save();
  }

  // ── sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _db.auth.signOut();
    await AppSettings.instance.clear();
  }

  // ── save prescription ─────────────────────────────────────────────────────

  /// Saves a completed scan+translation to the prescriptions table.
  /// Returns the UUID of the newly inserted row so the caller can prevent
  /// duplicate saves (store the ID and refuse a second save for the same scan).
  Future<String> savePrescription({
    required List<Map<String, dynamic>> medicines,
    required List<Map<String, dynamic>> translatedResults,
    required String targetLanguage,
  }) async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) throw 'Not logged in.';

    final row = await _db.from('prescriptions').insert({
      'patient_id':          uid,
      'medicines':           medicines,
      'translated_result':   translatedResults,
      'translated_language': targetLanguage,
    }).select('id').single();

    return row['id'] as String;
  }

  // ── prescription history ──────────────────────────────────────────────────

  /// Returns all prescriptions for the current user, newest first.
  Future<List<Map<String, dynamic>>> getPrescriptions() async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return [];

    final data = await _db
        .from('prescriptions')
        .select()
        .eq('patient_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data as List);
  }
}