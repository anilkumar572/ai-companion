import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechStatusCallback = void Function(String status);

class SpeechService {
  SpeechService({
    SpeechToText? speech,
    AudioRecorder? recorder,
  })  : _speech = speech ?? SpeechToText(),
        _recorder = recorder ?? AudioRecorder();

  final SpeechToText _speech;
  final AudioRecorder _recorder;
  bool _initialized = false;
  SpeechStatusCallback? _onStatus;
  String? _recordingPath;

  bool get isAvailable => _initialized;
  bool get isListening => _speech.isListening;
  Future<bool> isRecording() => _recorder.isRecording();

  Future<bool> initialize({SpeechStatusCallback? onStatus}) async {
    _onStatus = onStatus;
    _initialized = await _speech.initialize(
      onStatus: (status) => _onStatus?.call(status),
      onError: (_) {},
    );
    return _initialized;
  }

  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    Duration listenFor = const Duration(minutes: 2),
    Duration pauseFor = const Duration(seconds: 4),
    bool onDevice = true,
  }) async {
    if (!_initialized) {
      throw StateError('Speech recognition is not initialized.');
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        onDevice: onDevice,
        listenFor: listenFor,
        pauseFor: pauseFor,
      ),
    );
  }

  Future<void> startWakeWordListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
  }) {
    return startListening(
      onResult: onResult,
      onSoundLevel: onSoundLevel,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 2),
      onDevice: true,
    );
  }

  Future<void> startCommandRecording() async {
    if (await _recorder.hasPermission() == false) {
      throw StateError('Microphone permission is required for recording.');
    }

    final directory = await getTemporaryDirectory();
    _recordingPath =
        '${directory.path}/nova_command_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
  }

  Future<String?> stopCommandRecording() async {
    if (!await _recorder.isRecording()) {
      return _recordingPath;
    }

    final path = await _recorder.stop();
    return path ?? _recordingPath;
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    _recordingPath = null;
  }

  void dispose() {
    _speech.stop();
    _recorder.dispose();
  }
}
