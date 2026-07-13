import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../models/reminder.dart';
import '../models/translation_models.dart';
import '../services/auth_service.dart';
import '../services/app_settings.dart';
import '../services/ocr_service.dart';
import '../services/translation_service.dart';
import '../services/reminder_store.dart';
import '../theme/app_theme.dart';
import 'language_selection_screen.dart';

/// Full "Add Prescription" flow:
/// chooseMethod → imagePreview → ocrResult (with inline translate + reminders)
///              ↘ manualForm  ↗
class AddPrescriptionScreen extends StatefulWidget {
  const AddPrescriptionScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AddPrescriptionScreen> createState() => AddPrescriptionScreenState();
}

enum _Step { chooseMethod, imagePreview, ocrResult, manualForm }

const List<LanguageOption> kScanLanguages = [
  LanguageOption('हिंदी',  'Hindi',   'hi'),
  LanguageOption('বাংলা',  'Bengali', 'bn'),
  LanguageOption('தமிழ்',  'Tamil',   'ta'),
  LanguageOption('తెలుగు', 'Telugu',  'te'),
];

class AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  // ── Step / image ─────────────────────────────────────────────────────────
  _Step      _step       = _Step.chooseMethod;
  XFile?     _pickedFile;
  Uint8List? _imageBytes;
  bool       _isScanning = false;
  String?    _ocrError;
  List<MedicineInput>? _medicines;

  // ── Translation ───────────────────────────────────────────────────────────
  late String          _selectedLang;
  bool                 _isTranslating     = false;
  String?              _translateError;
  TranslationResponse? _translationResult;

  // ── Reminders ─────────────────────────────────────────────────────────────
  bool           _isGeneratingReminders = false;
  List<Reminder> _generatedReminders    = [];
  bool           _remindersAdded        = false;

  // ── Save ──────────────────────────────────────────────────────────────────
  bool    _isSaving = false;
  bool    _savedOk  = false;

  final _picker       = ImagePicker();
  final _ocrService   = OcrService();
  final _translateSvc = TranslationService();

  @override
  void initState() {
    super.initState();
    _selectedLang = AppSettings.instance.languageCode.isNotEmpty
        ? AppSettings.instance.languageCode
        : 'hi';
    if (!kScanLanguages.any((l) => l.code == _selectedLang)) {
      _selectedLang = kScanLanguages.first.code;
    }
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _translateSvc.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    await _prepareImage(file);
  }

  Future<void> _pickGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _prepareImage(file);
  }

  Future<void> _prepareImage(XFile file) async {
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedFile        = file;
      _imageBytes        = bytes;
      _step              = _Step.imagePreview;
      _ocrError          = null;
      _medicines         = null;
      _translationResult = null;
      _savedOk           = false;
      _remindersAdded    = false;
      _generatedReminders = [];
    });
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  Future<void> _runOcr() async {
    if (_pickedFile == null) return;
    setState(() {
      _isScanning        = true;
      _ocrError          = null;
      _medicines         = null;
      _translationResult = null;
      _savedOk           = false;
    });
    try {
      final result = await _ocrService.extractMedicines(_pickedFile!);
      setState(() { _medicines = result; _step = _Step.ocrResult; });
      // Automatically run translation when OCR finishes successfully!
      _runTranslation();
    } on OcrException catch (e) {
      setState(() => _ocrError = e.message);
    } catch (e) {
      setState(() => _ocrError = 'Something went wrong while scanning. Please try again.');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ── Translation ───────────────────────────────────────────────────────────

  Future<void> _runTranslation() async {
    final meds = _medicines;
    if (meds == null || meds.isEmpty) return;
    setState(() {
      _isTranslating     = true;
      _translateError    = null;
      _translationResult = null;
      _savedOk           = false;
    });
    try {
      final result = await _translateSvc.translateMedicines(
        targetLanguage: _selectedLang,
        medicines:      meds,
      );
      setState(() => _translationResult = result);
    } on TranslationException catch (e) {
      setState(() => _translateError = e.message);
    } catch (_) {
      setState(() => _translateError = 'Translation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  // ── Auto-generate reminders ───────────────────────────────────────────────

  Future<void> _addReminders() async {
    final meds = _medicines;
    if (meds == null || meds.isEmpty) return;

    // Check if any of these medicines already have reminders
    final existing = ReminderStore.instance.reminders;
    final existingMedicineIds = existing.map((r) => r.medicineId.toLowerCase()).toSet();
    final duplicates = meds.where((m) => existingMedicineIds.contains(m.name.toLowerCase())).toList();

    if (duplicates.isNotEmpty) {
      // Show confirmation popup listing the duplicate medicines
      final duplicateNames = duplicates.map((m) => m.name).join(', ');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Reminder Already Exists', style: TextStyle(color: AppColors.textDark)),
          content: Text(
            '$duplicateNames already ${duplicates.length == 1 ? 'has a' : 'have'} reminder${duplicates.length == 1 ? '' : 's'}. '
            'Existing reminders will be kept. Only new medicines will be added.',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add New Only'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isGeneratingReminders = true);
    try {
      final newReminders = await ReminderStore.instance.generateFromMedicines(meds);

      // Apply transliterated medicine name + bilingual timing label
      for (final r in newReminders) {
        if (_translationResult != null) {
          try {
            final trans = _translationResult!.results
                .firstWhere((res) => res.originalName.toLowerCase() == r.medicineId.toLowerCase());
            // Medicine name: TransliteratedName (English Name)
            r.medicineName = '${trans.medicineTransliterated} (${trans.originalName})';
            // Timing label: slot label (english timing from API)
            if (trans.timing.isNotEmpty) {
              r.timingLabel = '${r.timingLabel} (${trans.timing})';
            }
          } catch (_) {
            // No translation found, leave as is
          }
        }
      }
      // Persist updated names
      if (newReminders.isNotEmpty) {
        await ReminderStore.instance.persistNames(newReminders);
      }

      setState(() {
        _generatedReminders = newReminders;
        _remindersAdded     = true;
      });
      if (!mounted) return;
      final count = newReminders.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          count == 0
              ? 'All reminders already exist. Check the Reminder tab.'
              : '$count reminder${count == 1 ? '' : 's'} scheduled! Go to the Reminder tab to adjust times.',
        ),
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create reminders: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingReminders = false);
    }
  }

  // ── Save prescription to Supabase ─────────────────────────────────────────

  Future<void> _savePrescription() async {
    final meds   = _medicines;
    final result = _translationResult;
    if (meds == null) return;
    // Allow re-saving (e.g., different language) — no early-return guard

    setState(() { _isSaving = true; _savedOk = false; });
    try {
      await AuthService.instance.savePrescription(
        medicines: meds.map((m) => m.toJson()).toList(),
        translatedResults: result?.results
                .map((r) => {
                  'original_name': r.originalName,
                  'translated': r.translated,
                  'medicine_transliterated': r.medicineTransliterated,
                })
                .toList() ??
            [],
        targetLanguage: _selectedLang,
        imageBytes: _imageBytes,
      );
      setState(() { _savedOk = true; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Prescription saved! You can save again after translating to a new language.'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save prescription. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Back navigation ───────────────────────────────────────────────────────

  void _back() {
    switch (_step) {
      case _Step.chooseMethod:
        if (!widget.embedded) Navigator.of(context).maybePop();
      case _Step.imagePreview:
        setState(() { _step = _Step.chooseMethod; _ocrError = null; });
      case _Step.ocrResult:
        setState(() {
          _step = _Step.imagePreview;
          _medicines = null; _translationResult = null; _savedOk = false;
        });
      case _Step.manualForm:
        setState(() => _step = _Step.chooseMethod);
    }
  }

  bool handleBack() {
    if (_step == _Step.chooseMethod) return false;
    _back();
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _buildBody()));
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.chooseMethod:  return _buildChoiceView();
      case _Step.imagePreview:  return _buildImagePreview();
      case _Step.ocrResult:     return _buildOcrResult();
      case _Step.manualForm:    return _buildManualForm();
    }
  }

  // ── Method choice ──────────────────────────────────────────────────────────

  Widget _buildChoiceView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Prescription', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('How would you like to add your prescription?',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          SelectableRow(
            leadingIcon: Icons.camera_alt_outlined,
            title:    'Scan Prescription',
            subtitle: 'Take photo of the prescription',
            onTap:    _pickCamera,
          ),
          SelectableRow(
            leadingIcon: Icons.upload_outlined,
            title:    'Upload a Photo',
            subtitle: 'Pick an existing photo from your gallery',
            onTap:    _pickGallery,
          ),
          SelectableRow(
            leadingIcon: Icons.edit_outlined,
            title:    'Type Manually',
            subtitle: 'Enter medicine details yourself',
            onTap:    () => setState(() => _step = _Step.manualForm),
          ),
        ],
      ),
    );
  }

  // ── Image preview ──────────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 320,
              width: double.infinity,
              color: const Color(0xFF1F1E1C),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_imageBytes != null)
                    Image.memory(_imageBytes!, fit: BoxFit.contain),
                  CustomPaint(painter: _CornersPainter()),
                  if (_isScanning)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Reading prescription…',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_ocrError != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _ocrError!),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isScanning ? null : _runOcr,
              child: Text(_isScanning ? 'Scanning…' : 'Scan Prescription'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isScanning ? null : _pickGallery,
              child: const Text('Choose different image'),
            ),
          ),
        ],
      ),
    );
  }

  // ── OCR Result + Translation + Reminders ──────────────────────────────────

  Widget _buildOcrResult() {
    final meds = _medicines ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image thumbnail
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 18),

          // Detected medicines
          _SectionCard(
            headerLabel: 'DETECTED MEDICINES',
            headerColor: AppColors.cardCream,
            accentColor: AppColors.textMuted,
            bordered: false,
            children: meds
                .map((m) => _MedicineLine(
                      name:        m.name,
                      instructions: _rawInstruction(m),
                      highlighted: false,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // Language chips
          Wrap(
            spacing: 8,
            children: kScanLanguages.map((l) {
              final selected = _selectedLang == l.code;
              return ChoiceChip(
                label: Text(l.nativeLabel),
                selected: selected,
                selectedColor: AppColors.sage,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _selectedLang = l.code),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Translate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTranslating ? null : _runTranslation,
              child: _isTranslating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_translationResult == null ? 'Translate Prescription' : 'Re-translate'),
            ),
          ),

          if (_translateError != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _translateError!),
          ],

          // Translated result
          if (_translationResult != null) ...[
            const SizedBox(height: 20),
            _SectionCard(
              headerLabel: 'TRANSLATED → ${_nativeLabel(_selectedLang)}',
              headerColor: AppColors.cream,
              accentColor: AppColors.sageDark,
              bordered: true,
              children: _translationResult!.results
                  .map((r) => _MedicineLine(
                        name: r.medicineTransliterated.isNotEmpty
                            ? r.medicineTransliterated
                            : _translatedName(r.translated),
                        instructions: _extractInstruction(r.translated),
                        highlighted: true,
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),

          // ── Add Reminders ────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_remindersAdded) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.sageMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.sage),
                  ),
                  child: Row(children: [
                    const Icon(Icons.alarm_on, color: AppColors.sageDark, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_generatedReminders.length} reminder${_generatedReminders.length == 1 ? '' : 's'} scheduled.',
                        style: const TextStyle(color: AppColors.sageDark, fontSize: 12),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                onPressed: _isGeneratingReminders ? null : _addReminders,
                icon: _isGeneratingReminders
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_alarm_outlined, size: 18),
                label: Text(_isGeneratingReminders
                    ? 'Scheduling…'
                    : _remindersAdded ? 'Re-add / Update Reminders' : 'Add Reminders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Save Prescription ────────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_savedOk) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF5E7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle_outline, color: AppColors.sageDark, size: 16),
                    SizedBox(width: 8),
                    Text('Prescription saved!',
                        style: TextStyle(color: AppColors.sageDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _savePrescription,
                icon: _isSaving
                    ? const SizedBox(height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sageDark))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(_isSaving ? 'Saving…'
                    : _savedOk ? 'Save Again (New Language)' : 'Save Prescription'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: AppColors.sageDark,
                  side: const BorderSide(color: AppColors.sageDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _back,
              child: const Text('Re-scan'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Manual entry ──────────────────────────────────────────────────────────

  Widget _buildManualForm() {
    return _ManualEntryWidget(
      initialLanguage: _selectedLang,
      onSaved: (medicines) async {
        setState(() {
          _medicines  = medicines;
          _imageBytes = null;
          _step       = _Step.ocrResult;
        });
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _rawInstruction(MedicineInput m) {
    final parts = <String>[];
    if (m.frequency.isNotEmpty && m.frequency != 'Not specified') parts.add(m.frequency);
    if (m.duration.isNotEmpty  && m.duration  != 'Not specified') parts.add(m.duration);
    if (m.timing.isNotEmpty    && m.timing    != 'Not specified') parts.add(m.timing);
    return parts.join(' · ');
  }

  String _nativeLabel(String code) =>
      kScanLanguages.firstWhere((l) => l.code == code,
          orElse: () => kScanLanguages.first).nativeLabel;

  String _translatedName(String t) {
    final idx = t.indexOf('(');
    return idx > 1 ? t.substring(0, idx).trim() : t.trim();
  }

  /// Extracts instruction part after the ' — ' separator produced by the API template.
  /// e.g. "ऑगमेंटिन 625mg — दिन में दो बार लें" → "दिन में दो बार लें"
  String _extractInstruction(String translated) {
    final parts = translated.split(' — ');
    if (parts.length > 1) return parts.sublist(1).join(' — ').trim();
    // fallback: drop everything up to first dash
    final dashIdx = translated.indexOf('—');
    if (dashIdx > 0) return translated.substring(dashIdx + 1).trim();
    return '';
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
          Text(headerLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: accentColor)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _MedicineLine extends StatelessWidget {
  const _MedicineLine({
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
          SvgPicture.asset(
            'assets/SVG/newcapsule.svg',
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              highlighted ? AppColors.sageDark : AppColors.textMuted,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: highlighted ? AppColors.sageDark : AppColors.textDark)),
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(instructions,
                      style: TextStyle(
                          fontSize: 12,
                          color: highlighted
                              ? AppColors.sageDark.withValues(alpha: 0.8)
                              : AppColors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.sageMuted
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const l = 28.0, m = 16.0;
    canvas.drawLine(const Offset(m, m), const Offset(m + l, m), p);
    canvas.drawLine(const Offset(m, m), const Offset(m, m + l), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - l, m), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + l), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m + l, size.height - m), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - l), p);
    canvas.drawLine(Offset(size.width - m, size.height - m),
        Offset(size.width - m - l, size.height - m), p);
    canvas.drawLine(Offset(size.width - m, size.height - m),
        Offset(size.width - m, size.height - m - l), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── Manual entry ──────────────────────────────────────────────────────────────

class _ManualEntryWidget extends StatefulWidget {
  const _ManualEntryWidget({
    required this.initialLanguage,
    required this.onSaved,
  });
  final String initialLanguage;
  final Future<void> Function(List<MedicineInput>) onSaved;

  @override
  State<_ManualEntryWidget> createState() => _ManualEntryWidgetState();
}

class _ManualEntryWidgetState extends State<_ManualEntryWidget> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _freqCtrl   = TextEditingController();
  final _durCtrl    = TextEditingController();
  final _timingCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _freqCtrl.dispose();
    _durCtrl.dispose();
    _timingCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSaved([
      MedicineInput(
        name:      _nameCtrl.text.trim(),
        frequency: _freqCtrl.text.trim().isEmpty   ? 'Not specified' : _freqCtrl.text.trim(),
        duration:  _durCtrl.text.trim().isEmpty    ? 'Not specified' : _durCtrl.text.trim(),
        timing:    _timingCtrl.text.trim().isEmpty ? 'Not specified' : _timingCtrl.text.trim(),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enter Medicine Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          const FieldLabel('Medicine Name'),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Metformin 500mg'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 18),
          const FieldLabel('Frequency'),
          TextFormField(
            controller: _freqCtrl,
            decoration: const InputDecoration(hintText: 'e.g. BD / Twice daily'),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Duration'),
          TextFormField(
            controller: _durCtrl,
            decoration: const InputDecoration(hintText: 'e.g. 30 days'),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Timing'),
          TextFormField(
            controller: _timingCtrl,
            decoration: const InputDecoration(hintText: 'e.g. After food / Before breakfast'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Continue'),
            ),
          ),
        ]),
      ),
    );
  }
}