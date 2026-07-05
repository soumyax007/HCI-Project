import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_settings.dart';

/// Wraps Supabase auth + profile/prescription table operations.
///
/// Auth strategy: real email + password — no fake mobile-derived emails.
/// The Supabase auth UUID (auth.users.id) is used as the primary key for
/// every user-linked table (profiles, prescriptions, reminders).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── Sign Up ───────────────────────────────────────────────────────────────

  /// Creates a Supabase auth account with a real email address, then inserts
  /// a profile row linked via the auth UUID.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String age,
    required String mobile,
    required String languageCode,
    String caregiverName   = '',
    String caregiverMobile = '',
  }) async {
    // 1. Create auth account with real email
    final res = await _db.auth.signUp(email: email, password: password);

    final uid = res.user?.id;
    if (uid == null) throw 'Sign up failed — please try again.';

    // 2. Insert profile row — id = auth UUID
    await _db.from('profiles').insert({
      'id':                 uid,
      'name':               name,
      'age':                int.tryParse(age) ?? 0,
      'mobile':             mobile,
      'preferred_language': languageCode,
      'caregiver_name':     caregiverName,
      'caregiver_mobile':   caregiverMobile,
    });

    // 3. Persist to AppSettings + shared_preferences
    _applyToSettings(
      uid: uid, name: name, age: age, mobile: mobile,
      languageCode: languageCode,
      caregiverName: caregiverName, caregiverMobile: caregiverMobile,
    );
    await AppSettings.instance.save();
  }

  // ── Sign In ───────────────────────────────────────────────────────────────

  /// Signs in with email + password and loads the profile into [AppSettings].
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _db.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final uid = res.user?.id;
    if (uid == null) throw 'Login failed — check your email and password.';

    // Load profile from DB
    final row = await _db
        .from('profiles')
        .select()
        .eq('id', uid)
        .single();

    _applyToSettings(
      uid:            uid,
      name:           row['name']               as String? ?? '',
      age:            row['age']?.toString()     ?? '',
      mobile:         row['mobile']              as String? ?? '',
      languageCode:   row['preferred_language']  as String? ?? 'en',
      caregiverName:  row['caregiver_name']      as String? ?? '',
      caregiverMobile:row['caregiver_mobile']    as String? ?? '',
    );
    await AppSettings.instance.save();
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _db.auth.signOut();
    await AppSettings.instance.clear();
  }

  // ── Save Prescription ─────────────────────────────────────────────────────

  /// Inserts a prescription row owned by the current auth user.
  /// Returns the UUID of the new row (used to prevent duplicate saves).
  Future<String> savePrescription({
    required List<Map<String, dynamic>> medicines,
    required List<Map<String, dynamic>> translatedResults,
    required String targetLanguage,
  }) async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) throw 'Not logged in.';

    final row = await _db.from('prescriptions').insert({
      'user_id':             uid,          // FK → auth.users.id
      'medicines':           medicines,
      'translated_result':   translatedResults,
      'translated_language': targetLanguage,
    }).select('id').single();

    return row['id'] as String;
  }

  // ── Prescription History ──────────────────────────────────────────────────

  /// Returns all prescriptions for the current user, newest first.
  Future<List<Map<String, dynamic>>> getPrescriptions() async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return [];

    final data = await _db
        .from('prescriptions')
        .select()
        .eq('user_id', uid)         // uses user_id, not patient_id
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data as List);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _applyToSettings({
    required String uid,
    required String name,
    required String age,
    required String mobile,
    required String languageCode,
    required String caregiverName,
    required String caregiverMobile,
  }) {
    final s = AppSettings.instance;
    s.userId          = uid;
    s.name            = name;
    s.age             = age;
    s.mobile          = mobile;
    s.languageCode    = languageCode;
    s.caregiverName   = caregiverName;
    s.caregiverMobile = caregiverMobile;
    s.isLoggedIn      = true;
  }
}