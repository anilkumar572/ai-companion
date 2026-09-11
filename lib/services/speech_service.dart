import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  SpeechService() : _speech = SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  bool get isAvailable => _initialized;

  Future<bool> initialize() async {
    _initialized = await _speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    return _initialized;
  }

  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
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
        cancelOnError: true,
        onDevice: true,
      ),
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
