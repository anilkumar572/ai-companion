import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records audio and transcribes via worker POST /stt (Sarvam REST proxy).
/// More reliable on mobile than double WebSocket streaming.
class WorkerSttService {
  WorkerSttService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _recordingPath;
  bool _capturing = false;

  bool get isCapturing => _capturing;

  Future<void> startCapture() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required for recording.');
    }

    await stopCapture();

    final directory = await getTemporaryDirectory();
    _recordingPath =
        '${directory.path}/nova_stt_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
    _capturing = true;
  }

  Future<String> stopAndTranscribe({
    required String workerBaseUrl,
    required String installationId,
    String languageCode = 'unknown',
  }) async {
    final path = await stopCapture();
    if (path == null || path.isEmpty) {
      throw WorkerSttException('No audio was recorded');
    }

    final file = File(path);
    if (!await file.exists()) {
      throw WorkerSttException('Recorded audio file was not found');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw WorkerSttException('Recorded audio was empty');
    }

    final base = workerBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/stt');

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'installationId': installationId,
            'audioBase64': base64Encode(bytes),
            'language_code': languageCode,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw WorkerSttException(
        _extractError(response),
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final transcript = (data['transcript'] ?? '').toString().trim();
    if (transcript.isEmpty) {
      throw const WorkerSttException('Worker returned an empty transcript');
    }

    return transcript;
  }

  Future<String?> stopCapture() async {
    if (await _recorder.isRecording()) {
      final path = await _recorder.stop();
      _capturing = false;
      return path ?? _recordingPath;
    }
    _capturing = false;
    return _recordingPath;
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error']?.toString();
      final detail = data['detail']?.toString();
      if (error != null && detail != null) return '$error ($detail)';
      if (error != null) return error;
    } catch (_) {
      // Fall through.
    }
    return 'Worker STT failed (HTTP ${response.statusCode})';
  }

  Future<void> dispose() async {
    await stopCapture();
    await _recorder.dispose();
  }
}

class WorkerSttException implements Exception {
  const WorkerSttException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
