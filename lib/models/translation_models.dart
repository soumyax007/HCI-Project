/// A single medicine sent to the translation API.
class MedicineInput {
  const MedicineInput({
    required this.name,
    required this.frequency,
    required this.duration,
    required this.timing,
  });

  /// e.g. "Metformin 500mg"
  final String name;

  /// e.g. "OD" (once daily), "BD" (twice daily), "TDS" (thrice daily)
  final String frequency;

  /// e.g. "30 days"
  final String duration;

  /// e.g. "BF" (before food), "AF" (after food)
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
  });

  final String originalName;
  final String translated;
  final String method;

  factory TranslatedMedicineResult.fromJson(Map<String, dynamic> json) {
    return TranslatedMedicineResult(
      originalName: json['original_name'] as String? ?? '',
      translated: json['translated'] as String? ?? '',
      method: json['method'] as String? ?? '',
    );
  }
}

/// Full response from POST /translate:
/// { "target_language": "hi", "results": [ {...}, {...} ] }
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