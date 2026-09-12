import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CartesiaTtsService {
  const CartesiaTtsService();

  Future<Uint8List> synthesize({
    required String workerBaseUrl,
    required String installationId,
    required String text,
    required String language,
    required String gender,
    double speed = 1.0,
  }) async {
    final base = workerBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/tts');

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'installationId': installationId,
            'text': text,
            'language': language,
            'gender': gender,
            'speed': speed,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final message = _extractError(response);
      throw CartesiaTtsException(
        message,
        statusCode: response.statusCode,
      );
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const CartesiaTtsException('Cartesia returned empty audio');
    }
    if (bytes.length < 12 ||
        String.fromCharCodes(bytes.take(4)) != 'RIFF') {
      throw const CartesiaTtsException('Cartesia returned invalid audio data');
    }

    return Uint8List.fromList(bytes);
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error']?.toString();
      if (error != null && error.isNotEmpty) return error;
    } catch (_) {
      // Fall through to generic message.
    }
    return 'Cartesia TTS failed (HTTP ${response.statusCode})';
  }
}

class CartesiaTtsException implements Exception {
  const CartesiaTtsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
