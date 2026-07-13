import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/reminder.dart';

const String kTakenActionId  = 'dose_taken';
const String kSkipActionId   = 'dose_skip';
const String _pendingActionsPrefsKey = 'pending_dose_actions_v1';

/// Background handler — called when user taps a notification action while
/// the app is fully terminated. Persists the action for ReminderStore to
/// drain on next startup.
@pragma('vm:entry-point')
void notificationActionBackgroundHandler(NotificationResponse response) {
  _persistPendingAction(response);
}

Future<void> _persistPendingAction(NotificationResponse response) async {
  if (response.actionId != kTakenActionId && response.actionId != kSkipActionId) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_pendingActionsPrefsKey) ?? [];
    raw.add(jsonEncode({
      'reminderId': response.payload,
      'actionId':   response.actionId,
      'at':         DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_pendingActionsPrefsKey, raw);
  } catch (e) {
    debugPrint('Failed to persist background notification action: $e');
  }
}

Future<List<Map<String, String?>>> drainPendingNotificationActions() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_pendingActionsPrefsKey) ?? [];
    await prefs.remove(_pendingActionsPrefsKey);
    return raw.map((s) => Map<String, String?>.from(jsonDecode(s) as Map)).toList();
  } catch (_) {
    return [];
  }
}

/// Thin wrapper around flutter_local_notifications.
/// On web it plays the sound via audioplayers since local notifications
/// are not supported on that platform.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer();
  bool _initialized = false;

  void Function(String reminderId, DoseStatus status)? onAction;

  Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb) {
      tzdata.initializeTimeZones();
      try {
        final localTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTz));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      final darwinSettings  = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            'dose_reminder',
            actions: [
              DarwinNotificationAction.plain(kTakenActionId, 'Taken'),
              DarwinNotificationAction.plain(kSkipActionId,  'Skip'),
            ],
            options: {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
          ),
        ],
      );

      await _plugin.initialize(
        InitializationSettings(android: androidSettings, iOS: darwinSettings),
        onDidReceiveNotificationResponse:           _handleForegroundResponse,
        onDidReceiveBackgroundNotificationResponse: notificationActionBackgroundHandler,
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();

      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  void _handleForegroundResponse(NotificationResponse response) {
    HapticFeedback.mediumImpact();
    final reminderId = response.payload;
    if (reminderId == null) return;
    if (response.actionId == kTakenActionId) {
      onAction?.call(reminderId, DoseStatus.taken);
    } else if (response.actionId == kSkipActionId) {
      onAction?.call(reminderId, DoseStatus.skipped);
    }
  }

  // ── Web: play sound immediately ────────────────────────────────────────────

  /// Play the custom notification sound (web + mobile).
  /// On mobile this is triggered via the notification channel.
  Future<void> playSound() async {
    try {
      await _player.play(AssetSource('sounds/notification.wav'));
    } catch (e) {
      debugPrint('NotificationService.playSound failed: $e');
    }
  }

  // ── Native: schedule daily notification ───────────────────────────────────

  Future<void> scheduleDaily(Reminder reminder) async {
    if (!_initialized) await init();
    if (!reminder.enabled) {
      await cancel(reminder);
      return;
    }

    if (kIsWeb) {
      // Web doesn't support scheduled local notifications.
      // Reminder will fire via the in-app timer in ReminderScreen.
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'dose_reminders',
        'Medicine Reminders',
        channelDescription: 'Alerts you when it is time to take your medicine.',
        importance:       Importance.max,
        priority:         Priority.high,
        enableVibration:  true,
        playSound:        true,
        sound:            RawResourceAndroidNotificationSound('notification_sound'),
        category:         AndroidNotificationCategory.reminder,
        actions: [
          AndroidNotificationAction(kTakenActionId, 'Taken', showsUserInterface: false),
          AndroidNotificationAction(kSkipActionId,  'Skip',  showsUserInterface: false),
        ],
      ),
      iOS: DarwinNotificationDetails(
        sound:              'notification_sound.wav',
        categoryIdentifier: 'dose_reminder',
        presentAlert:       true,
        presentBadge:       true,
        presentSound:       true,
      ),
    );

    await _plugin.zonedSchedule(
      _notificationIdFor(reminder),
      'Time for ${reminder.medicineName}',
      '${reminder.dosageLabel} · ${reminder.timingLabel}',
      _nextInstanceOf(reminder.hour, reminder.minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: reminder.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(Reminder reminder) async {
    if (kIsWeb) return;
    await _plugin.cancel(_notificationIdFor(reminder));
  }

  int _notificationIdFor(Reminder reminder) =>
      reminder.id.hashCode & 0x7fffffff;

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now       = tz.TZDateTime.now(tz.local);
    var   scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
