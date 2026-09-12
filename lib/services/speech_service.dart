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
  String? _cachedLocaleId;
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
  }) async {
    if (!_initialized) {
      throw StateError('Speech recognition is not initialized.');
    }

    final hasPermission = await _speech.hasPermission;
    if (!hasPermission) {
      throw StateError('Microphone permission was denied.');
    }

    if (_sessionActive || _speech.isListening) {
      await shutdown(hardwareCooldown: true);
    }

    final resolvedLocale = await _resolveLocaleId(localeId);
    final started = await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel == null
          ? null
          : (level) => onSoundLevel(_normalizeSoundLevel(level)),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        // One session per tap — avoids Android's double listening chime.
        onDevice: resolvedLocale != null,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: resolvedLocale,
      ),
    );

    if (!started) {
      throw StateError('Could not start speech recognition on this device.');
    }

    _sessionActive = true;
  }

  /// Hard stop — releases mic immediately. Call before TTS playback.
  Future<void> shutdown({bool hardwareCooldown = true}) async {
    final wasActive = _sessionActive || _speech.isListening;
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

    // Only wait for Android mic release when something was actually listening.
    if (hardwareCooldown && wasActive) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> releaseMicrophone() => shutdown(hardwareCooldown: true);

  Future<void> dispose() async {
    await shutdown();
  }

  Future<String?> _resolveLocaleId(String? preferred) async {
    if (preferred == null || preferred.trim().isEmpty) {
      return _cachedLocaleId;
    }

    if (_cachedLocaleId != null) {
      return _cachedLocaleId;
    }

    final locales = await _speech.locales();
    if (locales.isEmpty) return null;

    final normalized = _normalizeLocale(preferred);
    for (final locale in locales) {
      if (_normalizeLocale(locale.localeId) == normalized) {
        return _cachedLocaleId = locale.localeId;
      }
    }

    final language = normalized.split('-').first;
    for (final locale in locales) {
      final localeNormalized = _normalizeLocale(locale.localeId);
      if (localeNormalized == language ||
          localeNormalized.startsWith('$language-')) {
        return _cachedLocaleId = locale.localeId;
      }
    }

    return null;
  }

  String _normalizeLocale(String locale) =>
      locale.trim().replaceAll('_', '-').toLowerCase();

  double _normalizeSoundLevel(double decibels) {
    return ((decibels + 45) / 35).clamp(0.0, 1.0);
  }

  String _formatError(SpeechRecognitionError error) {
    final message = error.errorMsg;
    if (message.isEmpty) {
      return 'Speech recognition is unavailable right now.';
    }

    return switch (message) {
      'error_network' || 'error_network_timeout' =>
        'No internet connection for speech recognition.',
      'error_permission' => 'Microphone permission is required.',
      'error_language_not_supported' || 'error_language_unavailable' =>
        'This language is not supported for speech on your device.',
      'error_speech_timeout' || 'error_no_match' =>
        'I did not catch that. Tap the orb and try again.',
      'error_busy' =>
        'Speech recognition is busy. Tap the orb to try again.',
      _ => message,
    };
  }
}
