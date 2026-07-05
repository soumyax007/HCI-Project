import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/translation_models.dart';

/// Thrown when the translation API call fails (network, non-200, or
/// malformed response) so the UI can show a clear, user-facing message.
class TranslationException implements Exception {
  TranslationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the teammate's Sarvam-AI-backed translation API.
///
/// Web-safe: uses `package:http` only, no `dart:io`, so this works on
/// Flutter Web as well as mobile/desktop.
class TranslationService {
  TranslationService({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint =
      'https://soumyax007-hci-translator-sarvam.hf.space/translate';

static const _timeout = Duration(seconds: 60);
  final http.Client _client;

  /// Sends [medicines] to be translated into [targetLanguage].
  ///
  /// [targetLanguage] must be one of: en, hi, bn, mr, ta, te, pa.
  /// Throws [TranslationException] on any failure.
  Future<TranslationResponse> translateMedicines({
    required String targetLanguage,
    required List<MedicineInput> medicines,
  }) async {
    final body = jsonEncode({
      'target_language': targetLanguage,
      'medicines': medicines.map((m) => m.toJson()).toList(),
    });

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
    } on Exception catch (e) {
      throw TranslationException('Could not reach the translation service: $e');
    }

    if (response.statusCode != 200) {
      throw TranslationException(
        'Translation failed (HTTP ${response.statusCode}). Please try again.',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw TranslationException('Received an unexpected response. Please try again.');
    }

    try {
      return TranslationResponse.fromJson(decoded);
    } catch (_) {
      throw TranslationException('Could not read the translated prescription.');
    }
  }

  void dispose() => _client.close();
}