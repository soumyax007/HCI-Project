import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/translation_models.dart';

/// Thrown when the OCR API call fails.
class OcrException implements Exception {
  OcrException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// POST https://ratio11-medocr.hf.space/extract
/// Accepts a prescription image, returns List<MedicineInput>.
class OcrService {
  OcrService({http.Client? client}) : _client = client ?? http.Client();

  static const _endpoint = 'https://ratio11-medocr.hf.space/extract';
  static const _timeout = Duration(seconds: 30);

  final http.Client _client;

  /// Uploads [image] and returns the structured medicines the OCR model
  /// extracted. Throws [OcrException] on any failure.
  Future<List<MedicineInput>> extractMedicines(XFile image) async {
    // Always read as bytes — works on Web, mobile, and desktop.
    final bytes = await image.readAsBytes();

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: image.name.isNotEmpty ? image.name : 'prescription.jpg',
        ),
      );

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on Exception catch (e) {
      throw OcrException('Could not reach the scanning service: $e');
    }

    if (response.statusCode != 200) {
      throw OcrException(
        'Scanning failed (HTTP ${response.statusCode}). '
        'Please try a clearer photo.',
      );
    }

    // Parse the structured response: { "medicines": [ {...}, ... ] }
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw OcrException('Unexpected response from the server. Please try again.');
    }

    final rawList = decoded['medicines'] as List<dynamic>? ?? [];
    if (rawList.isEmpty) {
      throw OcrException(
        'No medicines could be read from this photo. '
        'Try retaking it with better lighting.',
      );
    }

    return rawList
        .cast<Map<String, dynamic>>()
        .map((m) => MedicineInput(
              name: m['name'] as String? ?? '',
              frequency: m['frequency'] as String? ?? 'Not specified',
              duration: m['duration'] as String? ?? 'Not specified',
              timing: m['timing'] as String? ?? 'Not specified',
            ))
        .toList();
  }

  void dispose() => _client.close();
}