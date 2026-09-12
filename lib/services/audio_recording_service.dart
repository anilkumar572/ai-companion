import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  AudioRecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _activePath;

  bool get isRecording => _activePath != null;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start({
    void Function(double level)? onAmplitude,
  }) async {
    if (_activePath != null) {
      await stop();
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/nova_capture_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: path,
    );

    _activePath = path;

    if (onAmplitude != null) {
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amplitude) {
        onAmplitude(_normalizeAmplitude(amplitude.current));
      });
    }
  }

  Future<File?> stop() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final path = _activePath;
    _activePath = null;
    if (path == null) return null;

    final recordedPath = await _recorder.stop();
    final resolvedPath = recordedPath ?? path;
    final file = File(resolvedPath);
    if (!await file.exists() || await file.length() < 1200) {
      return null;
    }
    return file;
  }

  Future<void> cancel() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final path = _activePath;
    _activePath = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  double _normalizeAmplitude(double decibels) {
    // Typical speech falls between roughly -45 dBFS and -10 dBFS.
    return ((decibels + 45) / 35).clamp(0.0, 1.0);
  }
}
