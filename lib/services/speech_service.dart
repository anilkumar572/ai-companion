import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechStatusCallback = void Function(String status);

class SpeechService {
  SpeechService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  SpeechStatusCallback? _onStatus;

  bool get isAvailable => _initialized;
  bool get isListening => _speech.isListening;

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
        onDevice: true,
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
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void dispose() {
    _speech.stop();
  }
}
