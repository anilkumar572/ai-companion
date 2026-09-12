import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class SarvamSttService {
  const SarvamSttService();

  static const defaultEndpoint = 'https://api.sarvam.ai/speech-to-text';

  Future<String> transcribe({
    required String apiKey,
    required String audioPath,
    String endpoint = defaultEndpoint,
    String model = 'saaras:v3',
    String mode = 'transcribe',
    String languageCode = 'unknown',
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw SarvamSttException('Sarvam API key is not configured');
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      throw SarvamSttException('Recorded audio file was not found');
    }

    final request = http.MultipartRequest('POST', Uri.parse(endpoint))
      ..headers['api-subscription-key'] = key
      ..fields['model'] = model
      ..fields['mode'] = mode;

    if (languageCode.isNotEmpty && languageCode != 'unknown') {
      request.fields['language_code'] = languageCode;
    }

    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw SarvamSttException(
        _extractError(response),
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final transcript = (data['transcript'] ?? '').toString().trim();
    if (transcript.isEmpty) {
      throw const SarvamSttException('Sarvam returned an empty transcript');
    }

    return transcript;
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['message'] ?? data['error'] ?? data['detail'];
      if (message != null) return message.toString();
    } catch (_) {
      // Fall through.
    }
    return 'Sarvam STT failed (HTTP ${response.statusCode})';
  }
}

class SarvamSttException implements Exception {
  const SarvamSttException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
