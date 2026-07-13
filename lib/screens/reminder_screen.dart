import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../services/reminder_store.dart';
import '../theme/app_theme.dart';

/// Reminder tab — lists all scheduled reminders, lets the user:
///   • Edit the time (tap the clock).
///   • Toggle enable/disable.
///   • Mark today's dose as Taken or Skip.
///   • Delete the reminder.
///   • Add a manual reminder.
///
/// On web the screen also runs an in-app timer that fires the custom
/// notification sound when a scheduled reminder time is reached.
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  Timer? _webTimer;

  @override
  void initState() {
    super.initState();
    ReminderStore.instance.addListener(_onChanged);
    if (kIsWeb) _startWebTimer();
  }

  @override
  void dispose() {
    ReminderStore.instance.removeListener(_onChanged);
    _webTimer?.cancel();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  // ── Web timer: fires sound when a reminder time matches current time ───────

  void _startWebTimer() {
    _webTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      for (final r in ReminderStore.instance.reminders) {
        if (!r.enabled) continue;
        if (r.hour == now.hour && r.minute == now.minute) {
          NotificationService.instance.playSound();
          _showWebNotificationBanner(r);
        }
      }
    });
  }

  void _showWebNotificationBanner(Reminder reminder) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Row(children: [
          const Icon(Icons.alarm, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text('⏰ Time for ${reminder.medicineName}  —  ${reminder.dosageLabel} · ${reminder.timingLabel}'),
          ),
        ]),
        action: SnackBarAction(
          label: 'Taken',
          textColor: Colors.white,
          onPressed: () => ReminderStore.instance.logDose(reminder.id, DoseStatus.taken),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickTime(Reminder reminder) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (picked == null) return;
    await ReminderStore.instance.updateTime(reminder.id, picked.hour, picked.minute);
  }

  Future<void> _confirmDelete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text(
            'Remove the reminder for ${reminder.medicineName} at ${reminder.timeLabel}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ReminderStore.instance.deleteReminder(reminder.id);
    }
  }

  Future<void> _addManualReminder() async {
    final result = await showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddReminderSheet(),
    );
    if (result != null) {
      await ReminderStore.instance.addManualReminder(result);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reminders = [...ReminderStore.instance.reminders]
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    final summary = ReminderStore.instance.adherenceSummary();

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reminders', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                onPressed: _addManualReminder,
                icon: const Icon(Icons.add_circle_outline, color: AppColors.sageDark),
              ),
            ],
          ),
        ),
        if (summary.total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _AdherenceCard(summary: summary),
          ),
        Expanded(
          child: reminders.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  itemCount: reminders.length,
                  itemBuilder: (_, i) {
                    final r = reminders[i];
                    return _ReminderCard(
                      reminder: r,
                      onEditTime: () => _pickTime(r),
                      onToggle:   (v) => ReminderStore.instance.setEnabled(r.id, v),
                      onDelete:   () => _confirmDelete(r),
                      onTaken:    () => ReminderStore.instance.logDose(r.id, DoseStatus.taken),
                      onSkip:     () => ReminderStore.instance.logDose(r.id, DoseStatus.skipped),
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) return SafeArea(child: body);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reminders',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: body,
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No reminders yet',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
            SizedBox(height: 6),
            Text(
              'Scan a prescription to auto-generate reminders,\nor tap + to add one manually.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.summary});
  final ({int taken, int missed, int skipped, int total}) summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatChip(label: 'Taken',   value: summary.taken),
          _StatChip(label: 'Missed',  value: summary.missed),
          _StatChip(label: 'Skipped', value: summary.skipped),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final int    value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text('$value',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onEditTime,
    required this.onToggle,
    required this.onDelete,
    required this.onTaken,
    required this.onSkip,
  });

  final Reminder            reminder;
  final VoidCallback        onEditTime;
  final ValueChanged<bool>  onToggle;
  final VoidCallback        onDelete;
  final VoidCallback        onTaken;
  final VoidCallback        onSkip;

  @override
  Widget build(BuildContext context) {
    final todayStatus = reminder.todayLog?.status ?? DoseStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: reminder.enabled ? AppColors.sage : AppColors.border,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SvgPicture.asset(
              'assets/SVG/newcapsule.svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(AppColors.sageDark, BlendMode.srcIn),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reminder.medicineName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('${reminder.dosageLabel} · ${reminder.timingLabel}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
            Switch(
              value: reminder.enabled,
              activeThumbColor: AppColors.sageDark,
              onChanged: onToggle,
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            InkWell(
              onTap: onEditTime,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.sageDark),
                  const SizedBox(width: 6),
                  Text(reminder.timeLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.sageDark)),
                ]),
              ),
            ),
            const Spacer(),
            _TodayStatusPill(status: todayStatus),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
            ),
          ]),
          if (reminder.enabled && todayStatus == DoseStatus.pending) ...[
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onTaken,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    backgroundColor: AppColors.sageDark,
                  ),
                  child: const Text('Taken'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _TodayStatusPill extends StatelessWidget {
  const _TodayStatusPill({required this.status});
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color  color;
    late final Color  textColor;
    switch (status) {
      case DoseStatus.taken:
        label = 'Taken'; color = AppColors.sageMuted; textColor = AppColors.sageDark; break;
      case DoseStatus.missed:
        label = 'Missed'; color = AppColors.dangerBg; textColor = AppColors.danger; break;
      case DoseStatus.skipped:
        label = 'Skipped'; color = const Color(0xFFDDE3F0); textColor = const Color(0xFF5A6E96); break;
      case DoseStatus.pending:
        label = 'Pending'; color = const Color(0xFFF0DDB8); textColor = AppColors.warning; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

// ── Add Reminder Bottom Sheet ─────────────────────────────────────────────────

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet();
  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _dosageCtrl = TextEditingController();
  TimeOfDay _time   = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final reminder = Reminder(
      id:           'manual_${DateTime.now().microsecondsSinceEpoch}',
      medicineId:   'manual',
      medicineName: _nameCtrl.text.trim(),
      dosageLabel:  _dosageCtrl.text.trim().isNotEmpty ? _dosageCtrl.text.trim() : '1 dose',
      timingLabel:  'Manual',
      hour:         _time.hour,
      minute:       _time.minute,
    );
    Navigator.pop(context, reminder);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Reminder', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const FieldLabel('Medicine Name'),
          TextFormField(
            controller: _nameCtrl,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
          ),
          const SizedBox(height: 14),
          const FieldLabel('Dosage (optional)'),
          TextFormField(
            controller: _dosageCtrl,
            decoration: const InputDecoration(hintText: 'e.g. 1 tablet'),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Time'),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cardCream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.schedule, size: 18, color: AppColors.sageDark),
                const SizedBox(width: 8),
                Text(_time.format(context)),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _save, child: const Text('Save Reminder')),
          ),
        ]),
      ),
    );
  }
}
