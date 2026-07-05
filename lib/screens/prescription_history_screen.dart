import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

// ── Language name lookup (same codes as kScanLanguages) ───────────────────────
const _kLangNames = {
  'hi': 'Hindi',   'bn': 'Bengali', 'mr': 'Marathi',
  'ta': 'Tamil',   'te': 'Telugu',  'pa': 'Punjabi',
  'en': 'English',
};
String _langName(String code) => _kLangNames[code] ?? code.toUpperCase();

// ── Simple date formatter (no intl dependency) ────────────────────────────────
String _formatDate(String? isoString) {
  if (isoString == null) return '';
  final dt = DateTime.tryParse(isoString)?.toLocal();
  if (dt == null) return '';
  const months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m  = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ap';
}

// ── Data model ────────────────────────────────────────────────────────────────

class _PrescriptionRecord {
  _PrescriptionRecord({
    required this.id,
    required this.createdAt,
    required this.medicines,
    required this.translatedResult,
    required this.translatedLanguage,
  });

  final String id;
  final String createdAt;
  final List<Map<String, dynamic>> medicines;
  final List<Map<String, dynamic>> translatedResult;
  final String translatedLanguage;

  int get medicineCount => medicines.length;

  factory _PrescriptionRecord.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _list(dynamic v) =>
        (v as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

    return _PrescriptionRecord(
      id:                 json['id'] as String? ?? '',
      createdAt:          json['created_at'] as String? ?? '',
      medicines:          _list(json['medicines']),
      translatedResult:   _list(json['translated_result']),
      translatedLanguage: json['translated_language'] as String? ?? '',
    );
  }
}

// ── Prescription History Screen (list) ───────────────────────────────────────

class PrescriptionHistoryScreen extends StatefulWidget {
  const PrescriptionHistoryScreen({super.key});

  @override
  State<PrescriptionHistoryScreen> createState() =>
      _PrescriptionHistoryScreenState();
}

class _PrescriptionHistoryScreenState
    extends State<PrescriptionHistoryScreen> {
  List<_PrescriptionRecord>? _records;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _records = null; _error = null; });
    try {
      final rows = await AuthService.instance.getPrescriptions();
      setState(() {
        _records = rows.map(_PrescriptionRecord.fromJson).toList();
      });
    } catch (e) {
      setState(() => _error = 'Could not load history. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Prescription History',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading
    if (_records == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (_records!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.cardCream,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.description_outlined,
                    size: 36, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              const Text(
                'No prescriptions saved yet.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan and save your first prescription\nto see it here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    // List
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.sageDark,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: _records!.length,
        itemBuilder: (_, i) => _PrescriptionCard(
          record: _records![i],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PrescriptionDetailScreen(record: _records![i]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Prescription card ─────────────────────────────────────────────────────────

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({required this.record, required this.onTap});
  final _PrescriptionRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = _langName(record.translatedLanguage);
    final count = record.medicineCount;
    final date = _formatDate(record.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: AppColors.sage, width: 4)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined,
                  color: AppColors.sageDark, size: 22),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    _Chip(
                      icon: Icons.medication_outlined,
                      label: '$count medicine${count == 1 ? '' : 's'}',
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      icon: Icons.translate,
                      label: lang,
                    ),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Prescription Detail Screen ────────────────────────────────────────────────

class PrescriptionDetailScreen extends StatelessWidget {
  const PrescriptionDetailScreen({super.key, required this.record});
  final _PrescriptionRecord record;

  String _medicineName(Map<String, dynamic> m) =>
      m['name'] as String? ?? '—';

  String _medicineInstructions(Map<String, dynamic> m) {
    final parts = <String>[];
    final freq = m['frequency'] as String? ?? '';
    final dur  = m['duration']  as String? ?? '';
    final time = m['timing']    as String? ?? '';
    if (freq.isNotEmpty && freq != 'Not specified') parts.add(freq);
    if (dur.isNotEmpty  && dur  != 'Not specified') parts.add(dur);
    if (time.isNotEmpty && time != 'Not specified') parts.add(time);
    return parts.join(' · ');
  }

  String _translatedName(String t) {
    final idx = t.indexOf('(');
    return idx > 1 ? t.substring(0, idx).trim() : t.trim();
  }

  String _translatedInstr(String t) {
    final idx = t.indexOf('(');
    return idx > 1 ? t.substring(idx).trim() : '';
  }

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(record.createdAt);
    final lang = _langName(record.translatedLanguage);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Prescription',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── date header ─────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Saved on $date',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ]),
            const SizedBox(height: 20),

            // ── detected medicines ──────────────────────────────────────
            _DetailSection(
              headerLabel: 'DETECTED MEDICINES',
              headerColor: AppColors.cardCream,
              accentColor: AppColors.textMuted,
              bordered: false,
              children: record.medicines.isEmpty
                  ? [const _EmptyRow('No medicine data')]
                  : record.medicines.map((m) => _MedicineRow(
                        name: _medicineName(m),
                        instructions: _medicineInstructions(m),
                        highlighted: false,
                      )).toList(),
            ),
            const SizedBox(height: 16),

            // ── translated ──────────────────────────────────────────────
            if (record.translatedResult.isNotEmpty) ...[
              _DetailSection(
                headerLabel: 'TRANSLATED → $lang',
                headerColor: AppColors.cream,
                accentColor: AppColors.sageDark,
                bordered: true,
                children: record.translatedResult.map((r) {
                  final t = r['translated'] as String? ?? '';
                  return _MedicineRow(
                    name: _translatedName(t),
                    instructions: _translatedInstr(t),
                    highlighted: true,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets for detail screen ──────────────────────────────────────

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.headerLabel,
    required this.headerColor,
    required this.accentColor,
    required this.bordered,
    required this.children,
  });
  final String       headerLabel;
  final Color        headerColor;
  final Color        accentColor;
  final bool         bordered;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(14),
        border: bordered ? Border.all(color: AppColors.sageMuted) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({
    required this.name,
    required this.instructions,
    required this.highlighted,
  });
  final String name;
  final String instructions;
  final bool   highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted)
            Container(
              width: 3, height: 36,
              margin: const EdgeInsets.only(right: 10, top: 2),
              color: AppColors.sageDark,
            ),
          const Text('🌿', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: highlighted ? AppColors.sageDark : AppColors.textDark,
                  ),
                ),
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    instructions,
                    style: TextStyle(
                      fontSize: 12,
                      color: highlighted
                          ? AppColors.sageDark.withValues(alpha: 0.8)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted));
  }
}
