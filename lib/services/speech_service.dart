import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechStatusCallback = void Function(String status);
typedef SpeechErrorCallback = void Function(String message);

class SpeechService {
  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  SpeechStatusCallback? _onStatus;
  SpeechErrorCallback? _onError;

  bool get isAvailable => _initialized;
  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    SpeechStatusCallback? onStatus,
    SpeechErrorCallback? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    _initialized = await _speech.initialize(
      onStatus: (status) => _onStatus?.call(status),
      onError: (error) => _onError?.call(_formatError(error)),
    );
    return _initialized;
  }

  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    String? localeId,
    Duration listenFor = const Duration(seconds: 30),
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

    await releaseMicrophone();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final started = await _listenWithMode(
      onResult: onResult,
      onSoundLevel: onSoundLevel,
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      onDevice: onDevice,
      mode: ListenMode.confirmation,
    );

    if (started) return;

    final fallbackStarted = await _listenWithMode(
      onResult: onResult,
      onSoundLevel: onSoundLevel,
      localeId: localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      onDevice: onDevice,
      mode: ListenMode.dictation,
    );

    if (!fallbackStarted) {
      throw StateError('Could not start speech recognition on this device.');
    }
  }

  Future<bool> _listenWithMode({
    required void Function(String transcript, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    String? localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required bool onDevice,
    required ListenMode mode,
  }) async {
    return await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        listenMode: mode,
        partialResults: true,
        cancelOnError: true,
        onDevice: onDevice,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
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

  String _formatError(SpeechRecognitionError error) {
    if (error.errorMsg.isNotEmpty) return error.errorMsg;
    return 'Speech recognition is unavailable right now.';
  }
}
