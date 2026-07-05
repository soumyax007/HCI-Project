import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/translation_models.dart';
import '../services/ocr_service.dart';
import '../services/translation_service.dart';
import '../services/auth_service.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import 'language_selection_screen.dart';
import 'reminder_screen.dart';

/// The Scan tab — OCR + Translation on one scrollable page.
///
/// Flow:
///   chooseMethod → imagePreview → ocrResult (with inline translate)
///               ↘ manualForm   ↗
class AddPrescriptionScreen extends StatefulWidget {
  const AddPrescriptionScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AddPrescriptionScreen> createState() => AddPrescriptionScreenState();
}

enum _Step { chooseMethod, imagePreview, ocrResult, manualForm }

// ── language options (same list as old TranslateScreen) ─────────────────────
const List<LanguageOption> kScanLanguages = [
  LanguageOption('हिंदी',  'Hindi',   'hi'),
  LanguageOption('বাংলা',  'Bengali', 'bn'),
  LanguageOption('தமிழ்',  'Tamil',   'ta'),
  LanguageOption('తెలుగు', 'Telugu',  'te'),
];

class AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  // ── step / image state ───────────────────────────────────────────────────
  _Step         _step         = _Step.chooseMethod;
  XFile?        _pickedFile;
  Uint8List?    _imageBytes;
  bool          _isScanning   = false;
  String?       _ocrError;
  List<MedicineInput>? _medicines;

  // ── translation state ────────────────────────────────────────────────────
  late String          _selectedLang;
  bool                 _isTranslating   = false;
  String?              _translateError;
  TranslationResponse? _translationResult;
  bool                 _isSaving        = false;
  bool                 _savedOk         = false;
  String?              _savedPrescriptionId; // set after first save; prevents duplicates

  final _picker      = ImagePicker();
  final _ocrService  = OcrService();
  final _translateSvc = TranslationService();

  @override
  void initState() {
    super.initState();
    // default language chip = user's chosen language at sign-up
    _selectedLang = AppSettings.instance.languageCode.isNotEmpty
        ? AppSettings.instance.languageCode
        : 'hi';
    // If user chose 'en', default to first language chip (hi)
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

  // ── image picking ─────────────────────────────────────────────────────────

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
      _pickedFile = file;
      _imageBytes = bytes;
      _step       = _Step.imagePreview;
      _ocrError   = null;
      _medicines  = null;
      _translationResult = null;
      _savedOk    = false;
      _savedPrescriptionId = null;
    });
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  Future<void> _runOcr() async {
    if (_pickedFile == null) return;
    setState(() {
      _isScanning = true;
      _ocrError   = null;
      _medicines  = null;
      _translationResult = null;
      _savedOk    = false;
    });
    try {
      final result = await _ocrService.extractMedicines(_pickedFile!);
      setState(() { _medicines = result; _step = _Step.ocrResult; });
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
      _isTranslating   = true;
      _translateError  = null;
      _translationResult = null;
      _savedOk         = false;
    });

    try {
      final result = await _translateSvc.translateMedicines(
        targetLanguage: _selectedLang,
        medicines: meds,
      );
      setState(() => _translationResult = result);
    } on TranslationException catch (e) {
      setState(() => _translateError = e.message);
    } catch (e) {
      setState(() => _translateError = 'Translation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  // ── Save prescription to Supabase ─────────────────────────────────────────

  Future<void> _savePrescription() async {
    final meds   = _medicines;
    final result = _translationResult;
    if (meds == null || result == null) return;

    // Prevent saving the same scan twice
    if (_savedPrescriptionId != null) {
      setState(() => _savedOk = true);
      return;
    }

    setState(() { _isSaving = true; _savedOk = false; });

    try {
      final id = await AuthService.instance.savePrescription(
        medicines: meds.map((m) => m.toJson()).toList(),
        translatedResults: result.results
            .map((r) => {'original_name': r.originalName, 'translated': r.translated})
            .toList(),
        targetLanguage: _selectedLang,
      );
      setState(() {
        _savedPrescriptionId = id;
        _savedOk = true;
      });
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

  /// Called by MainShell when the user presses the AppBar back button or
  /// system back while the Scan tab is active.
  /// Returns true if the navigation was handled internally (step went back),
  /// or false if we are already at the root step (MainShell should go to Home).
  bool handleBack() {
    if (_step == _Step.chooseMethod) return false;
    _back();
    return true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.chooseMethod: return _buildChoiceView();
      case _Step.imagePreview: return _buildImagePreview();
      case _Step.ocrResult:    return _buildOcrResult();
      case _Step.manualForm:   return _buildChoiceView(); // unreachable but satisfies switch
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
          SelectableRow(leadingIcon: Icons.camera_alt_outlined,
            title: 'Scan Prescription', subtitle: 'Take photo of the prescription',
            onTap: _pickCamera),
          SelectableRow(leadingIcon: Icons.upload_outlined,
            title: 'Upload a Photo', subtitle: 'Pick an existing photo from your gallery',
            onTap: _pickGallery),
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
                      child: const Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text('Reading prescription…', style: TextStyle(color: Colors.white)),
                        ],
                      )),
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
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _isScanning ? null : _runOcr,
              child: Text(_isScanning ? 'Scanning…' : 'Scan Prescription'),
            )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: OutlinedButton(
              onPressed: _isScanning ? null : _pickGallery,
              child: const Text('Choose different image'),
            )),
        ],
      ),
    );
  }

  // ── OCR Result + inline Translation ───────────────────────────────────────

  Widget _buildOcrResult() {
    final meds = _medicines ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── thumbnail ────────────────────────────────────────────────
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

          // ── detected medicines ────────────────────────────────────────
          _SectionCard(
            headerLabel: 'DETECTED MEDICINES',
            headerColor: AppColors.cardCream,
            accentColor: AppColors.textMuted,
            bordered: false,
            children: meds.map((m) => _MedicineLine(
              name: m.name,
              instructions: _rawInstruction(m),
              highlighted: false,
            )).toList(),
          ),
          const SizedBox(height: 20),

          // ── translate button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTranslating ? null : _runTranslation,
              child: _isTranslating
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(_translationResult == null ? 'Translate Prescription' : 'Re-translate'),
            ),
          ),

          // ── translation error ─────────────────────────────────────────
          if (_translateError != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: _translateError!),
          ],

          // ── translated result ─────────────────────────────────────────
          if (_translationResult != null) ...[
            const SizedBox(height: 20),
            _SectionCard(
              headerLabel: 'TRANSLATED → ${_nativeLabel(_selectedLang)}',
              headerColor: AppColors.cream,
              accentColor: AppColors.sageDark,
              bordered: true,
              children: _translationResult!.results.map((r) => _MedicineLine(
                name: _translatedName(r.translated),
                instructions: _translatedInstructions(r.translated),
                highlighted: true,
              )).toList(),
            ),
            const SizedBox(height: 20),
            // ── add reminder button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReminderScreen(embedded: false)),
                ),
                icon: const Icon(Icons.add_alarm_outlined, size: 18),
                label: const Text('Add Reminder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ── save button ─────────────────────────────────────────────
            if (_savedOk)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF5E7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: AppColors.sageDark),
                    SizedBox(width: 8),
                    Text('Prescription saved!',
                      style: TextStyle(color: AppColors.sageDark, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _savePrescription,
                  icon: _isSaving
                      ? const SizedBox(height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sageDark))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Save Prescription'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: AppColors.sageDark,
                    side: const BorderSide(color: AppColors.sageDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
          ],

          const SizedBox(height: 10),
          // ── re-scan ───────────────────────────────────────────────────
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

  // ── Manual entry form ──────────────────────────────────────────────────────

  Widget _buildManualForm() {
    // Uses its own stateful subwidget so it can hold controllers
    return _ManualEntryWidget(
      initialLanguage: _selectedLang,
      onTranslate: (medicine) async {
        setState(() {
          _medicines = [medicine];
          _step      = _Step.ocrResult;
          _imageBytes = null;
        });
        await _runTranslation();
      },
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

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

  String _translatedInstructions(String t) {
    final idx = t.indexOf('(');
    return idx > 1 ? t.substring(idx).trim() : '';
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.headerLabel,
    required this.headerColor,
    required this.accentColor,
    required this.bordered,
    required this.children,
  });
  final String     headerLabel;
  final Color      headerColor;
  final Color      accentColor;
  final bool       bordered;
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
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                letterSpacing: 0.4, color: accentColor)),
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
            Container(width: 3, height: 36,
                margin: const EdgeInsets.only(right: 10, top: 2),
                color: AppColors.sageDark),
          const Text('🌿', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: highlighted ? AppColors.sageDark : AppColors.textDark)),
                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(instructions, style: TextStyle(
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
    final p = Paint()..color = AppColors.sageMuted..strokeWidth = 2..style = PaintingStyle.stroke;
    const l = 28.0, m = 16.0;
    canvas.drawLine(Offset(m, m), Offset(m + l, m), p);
    canvas.drawLine(Offset(m, m), Offset(m, m + l), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - l, m), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + l), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m + l, size.height - m), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - l), p);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m - l, size.height - m), p);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - l), p);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
      ]),
    );
  }
}

// ── Manual entry widget (stateful so it owns its controllers) ─────────────────

class _ManualEntryWidget extends StatefulWidget {
  const _ManualEntryWidget({
    required this.initialLanguage,
    required this.onTranslate,
  });
  final String initialLanguage;
  final Future<void> Function(MedicineInput) onTranslate;

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
    _nameCtrl.dispose(); _freqCtrl.dispose(); _durCtrl.dispose(); _timingCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onTranslate(MedicineInput(
      name:      _nameCtrl.text.trim(),
      frequency: _freqCtrl.text.trim().isEmpty   ? 'Not specified' : _freqCtrl.text.trim(),
      duration:  _durCtrl.text.trim().isEmpty    ? 'Not specified' : _durCtrl.text.trim(),
      timing:    _timingCtrl.text.trim().isEmpty ? 'Not specified' : _timingCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('Medicine Name'),
          TextFormField(controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Metformin 500mg'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 18),
          const FieldLabel('Frequency'),
          TextFormField(controller: _freqCtrl,
            decoration: const InputDecoration(hintText: 'e.g. BD / Twice daily')),
          const SizedBox(height: 18),
          const FieldLabel('Duration'),
          TextFormField(controller: _durCtrl,
            decoration: const InputDecoration(hintText: 'e.g. 30 days')),
          const SizedBox(height: 18),
          const FieldLabel('Timing'),
          TextFormField(controller: _timingCtrl,
            decoration: const InputDecoration(hintText: 'e.g. AF / After food')),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton(onPressed: _submit,
              child: const Text('Translate Prescription'))),
        ]),
      ),
    );
  }
}