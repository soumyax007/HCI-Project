import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/reminder.dart' as rm;
import '../services/reminder_store.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ReminderStore.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    ReminderStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ReminderStore.instance.reminders
        .where((r) => r.enabled)
        .toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    final summary = ReminderStore.instance.todayAdherenceSummary();
    final taken   = summary.taken;
    final total   = summary.total;

    final missed = reminders.where((r) => r.todayLog?.status == rm.DoseStatus.missed).toList();

    // Group by time-of-day buckets
    final morning   = reminders.where((r) => r.hour <  12).toList();
    final afternoon = reminders.where((r) => r.hour >= 12 && r.hour < 17).toList();
    final evening   = reminders.where((r) => r.hour >= 17).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          if (missed.isNotEmpty) ...[
            _MissedBanner(missed: missed),
            const SizedBox(height: 24),
          ],
          // Progress card
          _ProgressCard(taken: taken, total: total),
          const SizedBox(height: 24),

          if (reminders.isEmpty)
            const _EmptyHomeCard()
          else ...[
            if (morning.isNotEmpty)   _DoseGroup('Morning',   '🌅', morning),
            if (afternoon.isNotEmpty) _DoseGroup('Afternoon', '🌤️', afternoon),
            if (evening.isNotEmpty)   _DoseGroup('Evening',   '🌆', evening),
          ],
        ],
      ),
    );
  }
}

class _MissedBanner extends StatelessWidget {
  const _MissedBanner({required this.missed});
  final List<rm.Reminder> missed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text(
                'You missed ${missed.length} medicine${missed.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...missed.map((m) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('• ${m.medicineName} (${m.timeLabel})',
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          )),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.taken, required this.total});
  final int taken;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : taken / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's progress",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            total == 0 ? 'No reminders yet' : '$taken of $total doses taken',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeCard extends StatelessWidget {
  const _EmptyHomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/SVG/newcapsule.svg',
            width: 36,
            height: 36,
            colorFilter: const ColorFilter.mode(AppColors.sage, BlendMode.srcIn),
          ),
          const SizedBox(height: 12),
          const Text('No reminders scheduled',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text(
            'Scan a prescription in the Scan tab\nto auto-generate your daily reminders.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DoseGroup extends StatelessWidget {
  const _DoseGroup(this.title, this.emoji, this.reminders);
  final String title;
  final String emoji;
  final List<rm.Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ]),
        const SizedBox(height: 10),
        ...reminders.map((r) => _DoseCard(reminder: r)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.reminder});
  final rm.Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final todayStatus = reminder.todayLog?.status ?? rm.DoseStatus.pending;
    final isMissed    = todayStatus == rm.DoseStatus.missed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMissed ? AppColors.dangerBg : AppColors.cardCream,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: isMissed ? AppColors.danger : AppColors.sage,
            width: 4,
          ),
        ),
      ),
      child: Row(children: [
        SvgPicture.asset(
          'assets/SVG/newcapsule.svg',
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            isMissed ? AppColors.danger : AppColors.sageDark,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reminder.medicineName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(
                '${reminder.dosageLabel} · ${reminder.timeLabel} · ${reminder.timingLabel}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        _StatusPill(status: todayStatus),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final rm.DoseStatus status;

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color  color;
    late Color  textColor;

    switch (status) {
      case rm.DoseStatus.taken:
        label = 'Taken'; color = AppColors.sageMuted; textColor = AppColors.sageDark; break;
      case rm.DoseStatus.missed:
        label = 'Missed'; color = AppColors.dangerBg; textColor = AppColors.danger; break;
      case rm.DoseStatus.skipped:
        label = 'Skipped'; color = const Color(0xFFDDE3F0); textColor = const Color(0xFF5A6E96); break;
      case rm.DoseStatus.pending:
        label = 'Pending'; color = const Color(0xFFF0DDB8); textColor = AppColors.warning; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}