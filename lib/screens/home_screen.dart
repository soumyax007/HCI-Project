import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum DoseStatus { taken, dueSoon, upcoming, missed }

class DoseItem {
  const DoseItem({
    required this.name,
    required this.instructions,
    required this.time,
    required this.status,
  });

  final String name;
  final String instructions;
  final String time;
  final DoseStatus status;
}

class DoseSection {
  const DoseSection(this.title, this.emoji, this.items);
  final String title;
  final String emoji;
  final List<DoseItem> items;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // TODO: replace with real data from prescriptions / reminders backend.
  final List<DoseSection> _sections = const [
    DoseSection('Morning', '🌅', [
      DoseItem(
        name: 'Metformin 500mg',
        instructions: '1 tablet · 7:30 AM · Before food',
        time: '7:30 AM',
        status: DoseStatus.taken,
      ),
      DoseItem(
        name: 'Amlodipine 5mg',
        instructions: '1 tablet · 8:00 AM · After food',
        time: '8:00 AM',
        status: DoseStatus.taken,
      ),
    ]),
    DoseSection('Afternoon', '🌤️', [
      DoseItem(
        name: 'Atorvastatin 10mg',
        instructions: '1 tablet · 1:30 PM · After food',
        time: '1:30 PM',
        status: DoseStatus.dueSoon,
      ),
    ]),
    DoseSection('Evening', '🌆', [
      DoseItem(
        name: 'Pantoprazole 40mg',
        instructions: '1 tablet · 6:30 PM · Before food',
        time: '6:30 PM',
        status: DoseStatus.upcoming,
      ),
      DoseItem(
        name: 'Glimepiride 2mg',
        instructions: '1 tablet · 8:00 PM · After food',
        time: '8:00 PM',
        status: DoseStatus.missed,
      ),
    ]),
  ];

  int get _takenCount => _sections
      .expand((s) => s.items)
      .where((i) => i.status == DoseStatus.taken)
      .length;

  int get _totalCount => _sections.expand((s) => s.items).length;

  bool get _hasMissedDose =>
      _sections.expand((s) => s.items).any((i) => i.status == DoseStatus.missed);

  void _markTaken(DoseItem item) {
    setState(() {
      for (final section in _sections) {
        final idx = section.items.indexOf(item);
        if (idx != -1) {
          section.items[idx] = DoseItem(
            name: item.name,
            instructions: item.instructions,
            time: item.time,
            status: DoseStatus.taken,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          _ProgressCard(
            taken: _takenCount,
            total: _totalCount,
            showMissedNotice: _hasMissedDose,
          ),
          const SizedBox(height: 24),
          for (final section in _sections) ...[
            Row(
              children: [
                Text(section.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in section.items)
              _DoseCard(item: item, onTake: () => _markTaken(item)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.taken,
    required this.total,
    required this.showMissedNotice,
  });

  final int taken;
  final int total;
  final bool showMissedNotice;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : taken / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's progress",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '$taken of $total doses taken',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PlayfairDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
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
          if (showMissedNotice) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Priya (daughter) notified about missed dose',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.item, required this.onTake});

  final DoseItem item;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final isMissed = item.status == DoseStatus.missed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMissed ? AppColors.dangerBg : AppColors.cardCream,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isMissed ? AppColors.danger : AppColors.sage,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.instructions,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          _StatusWidget(status: item.status, onTake: onTake),
        ],
      ),
    );
  }
}

class _StatusWidget extends StatelessWidget {
  const _StatusWidget({required this.status, required this.onTake});

  final DoseStatus status;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case DoseStatus.taken:
        return const _Pill(label: 'Taken', color: AppColors.sageMuted, textColor: AppColors.sageDark);
      case DoseStatus.missed:
        return const _Pill(label: 'Missed', color: AppColors.dangerBg, textColor: AppColors.danger);
      case DoseStatus.dueSoon:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _Pill(label: 'Due Soon', color: Color(0xFFF0DDB8), textColor: AppColors.warning),
            const SizedBox(height: 6),
            _TakeButton(onTap: onTake),
          ],
        );
      case DoseStatus.upcoming:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _Pill(label: 'Upcoming', color: Color(0xFFDDE3F0), textColor: Color(0xFF5A6E96)),
            const SizedBox(height: 6),
            _TakeButton(onTap: onTake),
          ],
        );
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.textColor});
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

class _TakeButton extends StatelessWidget {
  const _TakeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sageDark,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 30),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: const Text('Take'),
      ),
    );
  }
}