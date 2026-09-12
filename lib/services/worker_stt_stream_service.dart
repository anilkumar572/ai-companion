import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WorkerSttStreamService {
  WorkerSttStreamService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _timeoutTimer;

  Future<void> startListening({
    required String workerBaseUrl,
    required String installationId,
    String languageCode = 'unknown',
    Duration listenFor = const Duration(seconds: 12),
    void Function(String transcript, bool isFinal)? onTranscript,
    void Function(String message)? onError,
    void Function()? onListening,
  }) async {
    await stopListening();

    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required for streaming STT.');
    }

    final wsUrl = _buildWsUrl(
      workerBaseUrl: workerBaseUrl,
      installationId: installationId,
      languageCode: languageCode,
    );

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    onListening?.call();

    _socketSub = _channel!.stream.listen(
      (event) => _handleSocketMessage(event, onTranscript, onError),
      onError: (error) => onError?.call('STT stream error: $error'),
      onDone: () {},
      cancelOnError: false,
    );

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _micSub = stream.listen((chunk) {
      if (chunk.isEmpty) return;
      final payload = jsonEncode({
        'audio': {
          'data': base64Encode(chunk),
          'sample_rate': 16000,
          'encoding': 'audio/wav',
        },
      });
      _channel?.sink.add(payload);
    });

    _timeoutTimer = Timer(listenFor, () async {
      await flush(onTranscript: onTranscript, onError: onError);
    });
  }

  Future<void> flush({
    void Function(String transcript, bool isFinal)? onTranscript,
    void Function(String message)? onError,
  }) async {
    try {
      _channel?.sink.add(jsonEncode({'type': 'flush'}));
    } catch (error) {
      onError?.call('Failed to flush STT stream: $error');
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await stopListening();
  }

  Future<void> stopListening() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    await _micSub?.cancel();
    _micSub = null;

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    await _socketSub?.cancel();
    _socketSub = null;

    await _channel?.sink.close();
    _channel = null;
  }

  void _handleSocketMessage(
    dynamic event,
    void Function(String transcript, bool isFinal)? onTranscript,
    void Function(String message)? onError,
  ) {
    try {
      final decoded = jsonDecode(event.toString()) as Map<String, dynamic>;
      final type = decoded['type']?.toString();
      final data = decoded['data'];

      if (type == 'error') {
        final message = data is Map
            ? (data['error'] ?? data['message'] ?? 'STT failed').toString()
            : 'STT failed';
        onError?.call(message);
        return;
      }

      if (type == 'events' && data is Map) {
        final signal = data['signal_type']?.toString();
        if (signal == 'END_SPEECH') {
          _channel?.sink.add(jsonEncode({'type': 'flush'}));
        }
        return;
      }

      if (type == 'data' && data is Map) {
        final transcript = (data['transcript'] ?? '').toString().trim();
        if (transcript.isNotEmpty) {
          onTranscript?.call(transcript, true);
        }
      }
    } catch (error) {
      onError?.call('Invalid STT stream message: $error');
    }
  }

  String _buildWsUrl({
    required String workerBaseUrl,
    required String installationId,
    required String languageCode,
  }) {
    final base = workerBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final wsBase = base
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/stt/ws').replace(
      queryParameters: {
        'installationId': installationId,
        'language_code': languageCode,
      },
    );
    return uri.toString();
  }

  Future<void> dispose() async {
    await stopListening();
    await _recorder.dispose();
  }
}
