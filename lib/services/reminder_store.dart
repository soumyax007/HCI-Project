import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';
import '../models/translation_models.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'reminder_generator.dart';

/// App-wide store for editable [Reminder]s and their dose history.
///
/// Persists locally via SharedPreferences and syncs to Supabase when
/// the user is logged in.
class ReminderStore extends ChangeNotifier {
  ReminderStore._();
  static final ReminderStore instance = ReminderStore._();

  static const _prefsKey = 'reminders_v2';

  final List<Reminder> _reminders = [];
  List<Reminder> get reminders => List.unmodifiable(_reminders);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;

    // 1. Try to load from Supabase (source of truth when logged in).
    bool fromCloud = false;
    try {
      final rows = await AuthService.instance.getReminders();
      if (rows.isNotEmpty) {
        _reminders
          ..clear()
          ..addAll(rows.map(Reminder.fromSupabase));
        fromCloud = true;
      }
    } catch (_) {}

    // 2. Fall back to SharedPreferences if cloud load failed or user offline.
    if (!fromCloud) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw   = prefs.getString(_prefsKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw) as List<dynamic>;
          _reminders
            ..clear()
            ..addAll(decoded.map((e) => Reminder.fromJson(e as Map<String, dynamic>)));
        }
      } catch (e) {
        debugPrint('ReminderStore.load (local) failed: $e');
      }
    }

    // 3. Re-schedule all enabled notifications.
    NotificationService.instance.onAction = _applyStatusById;
    await _applyPendingBackgroundActions();
    for (final r in _reminders) {
      if (r.enabled) {
        await NotificationService.instance.scheduleDaily(r);
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _applyPendingBackgroundActions() async {
    final pending = await drainPendingNotificationActions();
    for (final action in pending) {
      final reminderId = action['reminderId'];
      if (reminderId == null) continue;
      final status = action['actionId'] == kTakenActionId
          ? DoseStatus.taken
          : DoseStatus.skipped;
      _applyStatusById(reminderId, status, persist: false);
    }
    if (pending.isNotEmpty) await _persist();
  }

  // ── Generate from OCR medicines ───────────────────────────────────────────

  Future<List<Reminder>> generateFromMedicines(List<MedicineInput> medicines) async {
    // Build a set of existing (medicineId, timingLabel) pairs to avoid duplicates
    final existingKeys = _reminders
        .map((r) => '${r.medicineId.toLowerCase()}|${r.timingLabel.toLowerCase()}')
        .toSet();

    final candidates = ReminderGenerator.generateFromInputs(medicines);

    // Only keep reminders that don't already exist for the same medicine + slot
    final newReminders = candidates.where((r) {
      final key = '${r.medicineId.toLowerCase()}|${r.timingLabel.toLowerCase()}';
      return !existingKeys.contains(key);
    }).toList();

    if (newReminders.isNotEmpty) {
      _reminders.addAll(newReminders);
      for (final r in newReminders) {
        await NotificationService.instance.scheduleDaily(r);
        await _upsertToCloud(r);
      }
      notifyListeners();
      await _persist();
    }

    return newReminders;
  }

  /// After transliterated names are applied in the screen, call this to
  /// persist the updated medicineName / timingLabel values.
  Future<void> persistNames(List<Reminder> updated) async {
    for (final u in updated) {
      final idx = _reminders.indexWhere((r) => r.id == u.id);
      if (idx >= 0) {
        _reminders[idx].medicineName = u.medicineName;
        _reminders[idx].timingLabel  = u.timingLabel;
      }
    }
    notifyListeners();
    await _persist();
  }

  // ── Add manual reminder ───────────────────────────────────────────────────

  Future<void> addManualReminder(Reminder reminder) async {
    _reminders.add(reminder);
    await NotificationService.instance.scheduleDaily(reminder);
    await _upsertToCloud(reminder);
    notifyListeners();
    await _persist();
  }

  // ── Update time ───────────────────────────────────────────────────────────

  Future<void> updateTime(String id, int hour, int minute) async {
    final r = _find(id);
    if (r == null) return;
    r.hour   = hour;
    r.minute = minute;

    // Smart timing label update based on new hour
    if (hour >= 5 && hour < 12) {
      if (!r.timingLabel.toLowerCase().contains('morning') && !r.timingLabel.toLowerCase().contains('breakfast')) {
         r.timingLabel = 'Morning';
      }
    } else if (hour >= 12 && hour < 17) {
      if (!r.timingLabel.toLowerCase().contains('afternoon') && !r.timingLabel.toLowerCase().contains('lunch')) {
         r.timingLabel = 'Afternoon';
      }
    } else if (hour >= 17 && hour < 21) {
      if (!r.timingLabel.toLowerCase().contains('evening') && !r.timingLabel.toLowerCase().contains('dinner')) {
         r.timingLabel = 'Evening';
      }
    } else {
      if (!r.timingLabel.toLowerCase().contains('night') && !r.timingLabel.toLowerCase().contains('bedtime')) {
         r.timingLabel = 'Bedtime';
      }
    }

    await NotificationService.instance.scheduleDaily(r);
    await _upsertToCloud(r);
    notifyListeners();
    await _persist();
  }

  // ── Enable / disable ──────────────────────────────────────────────────────

  Future<void> setEnabled(String id, bool enabled) async {
    final r = _find(id);
    if (r == null) return;
    r.enabled = enabled;
    if (enabled) {
      await NotificationService.instance.scheduleDaily(r);
    } else {
      await NotificationService.instance.cancel(r);
    }
    await _upsertToCloud(r);
    notifyListeners();
    await _persist();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteReminder(String id) async {
    final r = _find(id);
    if (r == null) return;
    await NotificationService.instance.cancel(r);
    _reminders.removeWhere((rem) => rem.id == id);
    try {
      await AuthService.instance.deleteReminder(id);
    } catch (_) {}
    notifyListeners();
    await _persist();
  }

  // ── Log dose ──────────────────────────────────────────────────────────────

  Future<void> logDose(String id, DoseStatus status) async {
    _applyStatusById(id, status, persist: false);
    await _persist();
  }

  void _applyStatusById(String id, DoseStatus status, {bool persist = true}) {
    final r = _find(id);
    if (r == null) return;
    final now      = DateTime.now();
    final existing = r.todayLog;
    if (existing != null) {
      existing.status      = status;
      existing.completedAt = now;
    } else {
      r.history.add(DoseLog(scheduledFor: now, status: status, completedAt: now));
    }
    // if (status == DoseStatus.taken || status == DoseStatus.skipped) {
    //   NotificationService.instance.cancel(r).then((_) {
    //     if (r.enabled) {
    //       NotificationService.instance.scheduleDaily(r);
    //     }
    //   });
    // }
    notifyListeners();
    if (persist) {
      _persist();
      final summary = todayAdherenceSummary();
      AuthService.instance.logAdherence(summary.taken, summary.missed + summary.skipped);
    }
  }

  // ── Adherence summary ─────────────────────────────────────────────────────

  ({int taken, int missed, int skipped, int total}) todayAdherenceSummary() {
    var taken = 0, missed = 0, skipped = 0, total = 0;
    final now = DateTime.now();
    for (final r in _reminders) {
      for (final log in r.history) {
        if (log.scheduledFor.year == now.year && log.scheduledFor.month == now.month && log.scheduledFor.day == now.day) {
          total++;
          switch (log.status) {
            case DoseStatus.taken:   taken++;   break;
            case DoseStatus.missed:  missed++;  break;
            case DoseStatus.skipped: skipped++; break;
            case DoseStatus.pending: break;
          }
        }
      }
    }
    return (taken: taken, missed: missed, skipped: skipped, total: total);
  }

  ({int taken, int missed, int skipped, int total}) adherenceSummary() {
    var taken = 0, missed = 0, skipped = 0, total = 0;
    for (final r in _reminders) {
      for (final log in r.history) {
        total++;
        switch (log.status) {
          case DoseStatus.taken:   taken++;   break;
          case DoseStatus.missed:  missed++;  break;
          case DoseStatus.skipped: skipped++; break;
          case DoseStatus.pending: break;
        }
      }
    }
    return (taken: taken, missed: missed, skipped: skipped, total: total);
  }

  // ── Delete all (called on logout) ────────────────────────────────────────

  Future<void> deleteAll() async {
    for (final r in [..._reminders]) {
      await NotificationService.instance.cancel(r);
    }
    _reminders.clear();
    _loaded = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Reminder? _find(String id) {
    for (final r in _reminders) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _upsertToCloud(Reminder r) async {
    try {
      await AuthService.instance.upsertReminder(r.toJson());
    } catch (e) {
      debugPrint('ReminderStore.upsertToCloud failed: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = jsonEncode(_reminders.map((r) => r.toJson()).toList());
      await prefs.setString(_prefsKey, raw);
    } catch (e) {
      debugPrint('ReminderStore.persist failed: $e');
    }
  }
}
