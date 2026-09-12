import 'dart:convert';

import 'package:http/http.dart' as http;

class WorkerChatService {
  const WorkerChatService();

  Future<WorkerChatResponse> chat({
    required String workerBaseUrl,
    required String installationId,
    required String message,
    String language = 'auto',
    String personality = 'formal',
    String robotName = 'Nova',
    bool webSearchEnabled = true,
    List<WorkerChatTurn> conversationContext = const [],
    List<String> memoryNotes = const [],
  }) async {
    final base = workerBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat');

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'installationId': installationId,
            'message': message,
            'language': language,
            'personality': personality,
            'robotName': robotName,
            'webSearchEnabled': webSearchEnabled,
            'conversationContext': conversationContext
                .map((turn) => {'role': turn.role, 'content': turn.content})
                .toList(),
            'memoryNotes': memoryNotes,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw WorkerChatException(
        _extractError(response),
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final reply = (data['reply'] ?? '').toString().trim();
    if (reply.isEmpty) {
      throw const WorkerChatException('Worker returned an empty reply');
    }

    return WorkerChatResponse(
      reply: reply,
      language: (data['language'] ?? language).toString(),
      emotion: data['emotion']?.toString(),
    );
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error']?.toString();
      if (error != null && error.isNotEmpty) return error;
    } catch (_) {
      // Fall through.
    }
    return 'Worker chat failed (HTTP ${response.statusCode})';
  }
}

class WorkerChatTurn {
  const WorkerChatTurn({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;
}

class WorkerChatResponse {
  const WorkerChatResponse({
    required this.reply,
    required this.language,
    this.emotion,
  });

  final String reply;
  final String language;
  final String? emotion;
}

class WorkerChatException implements Exception {
  const WorkerChatException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
