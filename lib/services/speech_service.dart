import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechStatusCallback = void Function(String status);

class SpeechService {
  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

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
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 2),
    bool onDevice = true,
  }) async {
    if (!_initialized) {
      throw StateError('Speech recognition is not initialized.');
    }

    await releaseMicrophone();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
        onDevice: onDevice,
        listenFor: listenFor,
        pauseFor: pauseFor,
      ),
    );
  }

  /// Fully releases the microphone. Prefer this over [stopListening] when idle.
  Future<void> releaseMicrophone() async {
    if (!_initialized) return;

    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {
      try {
        await _speech.stop();
      } catch (_) {
        // Ignore — engine may already be stopped.
      }
    }
  }

  Future<void> stopListening() async {
    if (!_initialized || !_speech.isListening) return;
    try {
      await _speech.stop();
    } catch (_) {
      await releaseMicrophone();
    }
  }

  Future<void> dispose() async {
    await releaseMicrophone();
  }
}
