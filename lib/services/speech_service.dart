import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechStatusCallback = void Function(String status);
typedef SpeechErrorCallback = void Function(String message);

class SpeechService {
  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _sessionActive = false;
  SpeechStatusCallback? _onStatus;
  SpeechErrorCallback? _onError;

  bool get isAvailable => _initialized;
  bool get isListening => _speech.isListening || _sessionActive;

  Future<bool> initialize({
    SpeechStatusCallback? onStatus,
    SpeechErrorCallback? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    _initialized = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _sessionActive = false;
        }
        _onStatus?.call(status);
      },
      onError: (error) {
        _sessionActive = false;
        _onError?.call(_formatError(error));
      },
    );
    return _initialized;
  }

  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    String? localeId,
    Duration listenFor = const Duration(seconds: 12),
    Duration pauseFor = const Duration(seconds: 2),
    bool onDevice = true,
  }) async {
    if (!_initialized) {
      throw StateError('Speech recognition is not initialized.');
    }

    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      throw StateError('Microphone permission was denied.');
    }

    await shutdown();

    final started = await _speech.listen(
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
        localeId: localeId,
      ),
    );

    if (!started) {
      throw StateError('Could not start speech recognition on this device.');
    }

    _sessionActive = true;
  }

  /// Hard stop — releases mic immediately. Call before TTS playback.
  Future<void> shutdown() async {
    _sessionActive = false;
    if (!_initialized) return;

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}

    try {
      await _speech.cancel();
    } catch (_) {}

    // Let Android release the mic hardware before TTS takes audio focus.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> releaseMicrophone() => shutdown();

  Future<void> dispose() async {
    await shutdown();
  }

  String _formatError(SpeechRecognitionError error) {
    if (error.errorMsg.isNotEmpty) return error.errorMsg;
    return 'Speech recognition is unavailable right now.';
  }
}
