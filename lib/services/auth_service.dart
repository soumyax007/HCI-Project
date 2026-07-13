import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_settings.dart';

/// Wraps Supabase auth + profile/prescription/reminder table operations.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── Sign Up ───────────────────────────────────────────────────────────────

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
    final res = await _db.auth.signUp(email: email, password: password);
    final uid = res.user?.id;
    if (uid == null) throw 'Sign up failed — please try again.';

    await _db.from('profiles').insert({
      'id':                 uid,
      'name':               name,
      'age':                int.tryParse(age) ?? 0,
      'mobile':             mobile,
      'preferred_language': languageCode,
      'caregiver_name':     caregiverName,
      'caregiver_mobile':   caregiverMobile,
    });

    _applyToSettings(
      uid: uid, name: name, age: age, mobile: mobile,
      languageCode: languageCode,
      caregiverName: caregiverName, caregiverMobile: caregiverMobile,
    );
    await AppSettings.instance.save();
  }

  // ── Update Profile ────────────────────────────────────────────────────────

  Future<void> updateProfile({
    required String mobile,
    required String caregiverName,
    required String caregiverMobile,
  }) async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return;

    await _db.from('profiles').update({
      'mobile':           mobile,
      'caregiver_name':   caregiverName,
      'caregiver_mobile': caregiverMobile,
    }).eq('id', uid);

    final s = AppSettings.instance;
    _applyToSettings(
      uid:             uid,
      name:            s.name,
      age:             s.age,
      mobile:          mobile,
      languageCode:    s.languageCode,
      caregiverName:   caregiverName,
      caregiverMobile: caregiverMobile,
    );
    await s.save();
  }

  // ── Sign In ───────────────────────────────────────────────────────────────

  Future<void> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    final isEmail = emailOrPhone.contains('@');
    final res = isEmail
        ? await _db.auth.signInWithPassword(email: emailOrPhone, password: password)
        : await _db.auth.signInWithPassword(phone: emailOrPhone, password: password);
    final uid = res.user?.id;
    if (uid == null) throw 'Login failed — check your email and password.';

    final row = await _db.from('profiles').select().eq('id', uid).single();
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

  // ── Google Sign In ────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_CLIENT_ID'];
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: webClientId,
      serverClientId: kIsWeb ? null : webClientId,
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw 'Google sign in aborted.';
    
    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null || idToken == null) {
      throw 'Missing Google Auth Tokens';
    }

    final res = await _db.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    
    final uid = res.user?.id;
    if (uid == null) throw 'Login failed.';

    // Check if profile exists, if not create dummy
    final data = await _db.from('profiles').select().eq('id', uid).maybeSingle();
    if (data == null) {
      final name = res.user?.userMetadata?['full_name'] ?? 'Google User';
      await _db.from('profiles').insert({
        'id': uid,
        'name': name,
        'age': 0,
        'mobile': '',
        'preferred_language': 'en',
        'caregiver_name': '',
        'caregiver_mobile': '',
      });
      _applyToSettings(
        uid: uid, name: name, age: '', mobile: '',
        languageCode: 'en', caregiverName: '', caregiverMobile: '',
      );
    } else {
      _applyToSettings(
        uid: uid,
        name: data['name'] as String? ?? '',
        age: data['age']?.toString() ?? '',
        mobile: data['mobile'] as String? ?? '',
        languageCode: data['preferred_language'] as String? ?? 'en',
        caregiverName: data['caregiver_name'] as String? ?? '',
        caregiverMobile: data['caregiver_mobile'] as String? ?? '',
      );
    }
    await AppSettings.instance.save();
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<void> sendOtp(String email, String otp) async {
    final apiKey = dotenv.env['RESEND_API_KEY'];
    if (apiKey == null) throw 'Missing Resend API Key';

    try {
      final res = await http.post(
        // Use a CORS proxy if running on Web to avoid "Failed to fetch"
        Uri.parse('https://corsproxy.io/?https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "from": "onboarding@resend.dev",
          "to": [email],
          "subject": "Medi Care Verification Code",
          "html": "<p>Your Medi Care verification code is: <strong>$otp</strong></p>"
        }),
      );
      if (res.statusCode >= 300) {
        throw 'Failed to send OTP email: ${res.body}';
      }
    } catch (e) {
      if (e.toString().contains('Failed to fetch')) {
        throw 'Failed to connect to email server. Make sure you are not blocked by CORS or an adblocker.';
      }
      rethrow;
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _db.auth.resetPasswordForEmail(email);
  }

  // ── Update Password ───────────────────────────────────────────────────────
  Future<void> updatePassword(String newPassword) async {
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _db.auth.signOut();
    await AppSettings.instance.clear();
  }

  // ── Save Prescription ─────────────────────────────────────────────────────

  /// Returns the UUID of the inserted row.
  Future<String> savePrescription({
    required List<Map<String, dynamic>> medicines,
    required List<Map<String, dynamic>> translatedResults,
    required String targetLanguage,
    Uint8List? imageBytes,
  }) async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) throw 'Not logged in.';

    String? imageUrl;
    if (imageBytes != null) {
      final fileName = 'prescription_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$uid/$fileName';
      
      try {
        await _db.storage.from('prescriptions').uploadBinary(
          filePath,
          imageBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        imageUrl = _db.storage.from('prescriptions').getPublicUrl(filePath);
      } catch (e) {
        // ignore storage errors to avoid blocking the save, or we can rethrow
        // but it's better to just skip imageUrl if it fails for now
      }
    }

    final row = await _db.from('prescriptions').insert({
      'user_id':             uid,
      'medicines':           medicines,
      'translated_result':   translatedResults,
      'translated_language': targetLanguage,
      if (imageUrl != null) 'image_url': imageUrl,
    }).select('id').single();

    return row['id'] as String;
  }

  // ── Get Prescriptions ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPrescriptions() async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return [];

    final data = await _db
        .from('prescriptions')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data as List);
  }

  // ── Reminders Supabase CRUD ───────────────────────────────────────────────

  Future<void> upsertReminder(Map<String, dynamic> reminderJson) async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return;
    await _db.from('reminders').upsert({
      'id':            reminderJson['id'],
      'user_id':       uid,
      'medicine_id':   reminderJson['medicineId']   ?? '',
      'medicine_name': reminderJson['medicineName'] ?? '',
      'dosage_label':  reminderJson['dosageLabel']  ?? '',
      'timing_label':  reminderJson['timingLabel']  ?? '',
      'hour':          reminderJson['hour']         ?? 8,
      'minute':        reminderJson['minute']       ?? 0,
      'enabled':       reminderJson['enabled']      ?? true,
    });
  }

  Future<void> deleteReminder(String id) async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return;
    await _db.from('reminders').delete().eq('id', id).eq('user_id', uid);
  }

  // ── Daily Adherence ───────────────────────────────────────────────────────

  Future<void> logAdherence(int taken, int missed) async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return;
    
    // date as YYYY-MM-DD
    final dateStr = DateTime.now().toIso8601String().split('T')[0];

    try {
      await _db.from('daily_adherence').upsert({
        'user_id': uid,
        'date': dateStr,
        'taken_count': taken,
        'missed_count': missed,
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    final uid = AppSettings.instance.userId;
    if (uid.isEmpty) return [];
    final data = await _db
        .from('reminders')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: true);
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