import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class WorkerSttService {
  const WorkerSttService();

  Future<String> transcribe({
    required String workerBaseUrl,
    required String installationId,
    required File audioFile,
    required String languageCode,
  }) async {
    final base = workerBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/stt');
    final audioBytes = await audioFile.readAsBytes();

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'installationId': installationId,
            'audioBase64': base64Encode(audioBytes),
            'language_code': languageCode,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 404) {
      throw WorkerSttException(
        'Cloud speech is not available yet. Deploy the latest worker.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw WorkerSttException(
        _extractError(response),
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final transcript = (body['transcript'] as String?)?.trim() ?? '';
    if (transcript.isEmpty) {
      throw WorkerSttException('Cloud speech returned an empty transcript.');
    }
    return transcript;
  }

  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['error'] ?? body['detail'] ?? body['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {}
    return 'Cloud speech failed (${response.statusCode}).';
  }
}

class WorkerSttException implements Exception {
  WorkerSttException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
