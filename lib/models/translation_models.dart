/// A single medicine sent to the translation API.
class MedicineInput {
  const MedicineInput({
    required this.name,
    required this.frequency,
    required this.duration,
    required this.timing,
  });

  final String name;
  final String frequency;
  final String duration;
  final String timing;

  Map<String, dynamic> toJson() => {
        'name': name,
        'frequency': frequency,
        'duration': duration,
        'timing': timing,
      };
}

/// One entry in the API's `results` array.
class TranslatedMedicineResult {
  const TranslatedMedicineResult({
    required this.originalName,
    required this.translated,
    required this.method,
    required this.medicineTransliterated,
    this.frequency = '',
    this.timing = '',
    this.duration = '',
  });

  /// Original English medicine name e.g. "Augmentin 625mg"
  final String originalName;

  /// Full translated instruction string e.g. "ऑगमेंटिन 625mg — दिन में दो बार लें..."
  final String translated;

  /// Only the transliterated medicine name e.g. "ऑगमेंटिन 625mg"
  /// This is what gets used in reminders.
  final String medicineTransliterated;

  /// Normalised English frequency e.g. "twice daily"
  final String frequency;

  /// Normalised English timing e.g. "after food"
  final String timing;

  /// Duration e.g. "5"
  final String duration;

  final String method;

  factory TranslatedMedicineResult.fromJson(Map<String, dynamic> json) {
    return TranslatedMedicineResult(
      originalName:           json['original_name']           as String? ?? '',
      translated:             json['translated']              as String? ?? '',
      medicineTransliterated: json['medicine_transliterated'] as String? ??
          json['original_name']                               as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      timing:    json['timing']    as String? ?? '',
      duration:  json['duration']  as String? ?? '',
      method:    json['method']    as String? ?? '',
    );
  }
}

/// Full response from POST /translate.
class TranslationResponse {
  const TranslationResponse({
    required this.targetLanguage,
    required this.results,
  });

  final String targetLanguage;
  final List<TranslatedMedicineResult> results;

  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? const [];
    return TranslationResponse(
      targetLanguage: json['target_language'] as String? ?? '',
      results: rawResults
          .cast<Map<String, dynamic>>()
          .map(TranslatedMedicineResult.fromJson)
          .toList(),
    );
  }
}