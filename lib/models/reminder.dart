/// Status of a single scheduled dose.
enum DoseStatus { pending, taken, missed, skipped }

/// A single logged occurrence of a reminder firing.
class DoseLog {
  DoseLog({
    required this.scheduledFor,
    required this.status,
    this.completedAt,
  });

  final DateTime scheduledFor;
  DoseStatus status;
  DateTime? completedAt;

  Map<String, dynamic> toJson() => {
        'scheduledFor': scheduledFor.toIso8601String(),
        'status':       status.name,
        'completedAt':  completedAt?.toIso8601String(),
      };

  factory DoseLog.fromJson(Map<String, dynamic> json) => DoseLog(
        scheduledFor: DateTime.parse(json['scheduledFor'] as String),
        status: DoseStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => DoseStatus.pending,
        ),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
      );
}

/// An editable, user-facing reminder for one dose slot of one medicine.
class Reminder {
  Reminder({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.dosageLabel,
    required this.timingLabel,
    required this.hour,
    required this.minute,
    this.enabled = true,
    List<DoseLog>? history,
  }) : history = history ?? [];

  final String id;
  final String medicineId;
  String medicineName;
  final String dosageLabel;
  String timingLabel;
  int    hour;
  int    minute;
  bool   enabled;
  final List<DoseLog> history;

  String get timeLabel {
    final h      = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }

  DoseLog? get todayLog {
    final now = DateTime.now();
    for (final log in history.reversed) {
      if (log.scheduledFor.year  == now.year  &&
          log.scheduledFor.month == now.month &&
          log.scheduledFor.day   == now.day) {
        return log;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id':           id,
        'medicineId':   medicineId,
        'medicineName': medicineName,
        'dosageLabel':  dosageLabel,
        'timingLabel':  timingLabel,
        'hour':         hour,
        'minute':       minute,
        'enabled':      enabled,
        'history':      history.map((h) => h.toJson()).toList(),
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id:           json['id']           as String,
        medicineId:   (json['medicineId']  as String?) ?? '',
        medicineName: (json['medicineName']as String?) ?? '',
        dosageLabel:  (json['dosageLabel'] as String?) ?? '',
        timingLabel:  (json['timingLabel'] as String?) ?? '',
        hour:         (json['hour']   as num?)?.toInt() ?? 8,
        minute:       (json['minute'] as num?)?.toInt() ?? 0,
        enabled:      (json['enabled'] as bool?) ?? true,
        history: (json['history'] as List<dynamic>? ?? [])
            .map((h) => DoseLog.fromJson(h as Map<String, dynamic>))
            .toList(),
      );

  /// Build from a Supabase reminders row.
  factory Reminder.fromSupabase(Map<String, dynamic> row) => Reminder(
        id:           row['id']            as String,
        medicineId:   (row['medicine_id']  as String?) ?? '',
        medicineName: (row['medicine_name']as String?) ?? '',
        dosageLabel:  (row['dosage_label'] as String?) ?? '',
        timingLabel:  (row['timing_label'] as String?) ?? '',
        hour:         (row['hour']   as num?)?.toInt() ?? 8,
        minute:       (row['minute'] as num?)?.toInt() ?? 0,
        enabled:      (row['enabled'] as bool?) ?? true,
      );
}
