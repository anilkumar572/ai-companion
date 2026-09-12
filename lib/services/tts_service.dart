import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/tts_engine.dart';
import '../models/voice_gender.dart';
import 'cartesia_tts_service.dart';

class TtsService {
  TtsService({
    SharedPreferences? prefs,
    CartesiaTtsService? cartesia,
    AudioPlayer? audioPlayer,
  })  : _prefs = prefs,
        _cartesia = cartesia ?? const CartesiaTtsService(),
        _tts = FlutterTts(),
        _audioPlayer = audioPlayer ?? AudioPlayer();

  final FlutterTts _tts;
  final CartesiaTtsService _cartesia;
  final AudioPlayer _audioPlayer;
  final SharedPreferences? _prefs;

  VoiceGender _gender = VoiceGender.female;
  TtsEngine _engine = TtsEngine.device;
  bool _initialized = false;
  StreamSubscription<void>? _playbackCompleteSub;

  static const _femaleVoiceKey = 'tts_voice_female';
  static const _maleVoiceKey = 'tts_voice_male';

  TtsEngine get engine => _engine;

  String get workerUrl => NovaConstants.workerUrl;

  String get preferredLanguage =>
      _prefs?.getString(NovaConstants.prefsPreferredLanguage) ??
      NovaConstants.defaultLanguage;

  String get installationId {
    final saved = _prefs?.getString(NovaConstants.prefsInstallationId);
    if (saved != null && saved.isNotEmpty) return saved;
    final generated = const Uuid().v4();
    _prefs?.setString(NovaConstants.prefsInstallationId, generated);
    return generated;
  }

  Future<void> initialize({VoiceGender gender = VoiceGender.female}) async {
    _gender = gender;
    _engine = TtsEngine.fromStorage(_prefs?.getString(NovaConstants.prefsTtsEngine));
    await _initializeDeviceTts(gender);
    _initialized = true;
  }

  Future<void> setEngine(TtsEngine engine, {bool preview = false}) async {
    _engine = engine;
    await _prefs?.setString(NovaConstants.prefsTtsEngine, engine.storageKey);
    if (preview) {
      await speak(_previewText());
    }
  }

  Future<void> setPreferredLanguage(String language) async {
    await _prefs?.setString(
      NovaConstants.prefsPreferredLanguage,
      language.trim(),
    );
  }

  Future<void> setGender(VoiceGender gender, {bool preview = false}) async {
    _gender = gender;
    if (!_initialized) {
      await initialize(gender: gender);
    } else if (_engine == TtsEngine.device) {
      await _tts.setPitch(gender == VoiceGender.male ? 0.92 : 1.02);
      await _applyDeviceVoice(gender);
    }

    if (preview) {
      await speak(_previewText());
    }
  }

  Future<void> speak(
    String text, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
    String? languageOverride,
  }) async {
    if (!_initialized) {
      await initialize(gender: _gender);
    }

    final prepared = _prepareSpeechText(text);
    if (prepared.isEmpty) {
      onComplete?.call();
      return;
    }

    await stop();

    if (_engine == TtsEngine.cartesia) {
      await _speakWithCartesia(
        prepared,
        onStart: onStart,
        onComplete: onComplete,
        languageOverride: languageOverride,
      );
      return;
    }

    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setErrorHandler((_) => onComplete?.call());
    await _tts.speak(prepared);
  }

  Future<void> stop() async {
    await _playbackCompleteSub?.cancel();
    _playbackCompleteSub = null;
    await _audioPlayer.stop();
    await _tts.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
  }

  Future<void> _speakWithCartesia(
    String text, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
    String? languageOverride,
  }) async {
    try {
      final audio = await _cartesia.synthesize(
        workerBaseUrl: workerUrl,
        installationId: installationId,
        text: text,
        language: languageOverride ?? preferredLanguage,
        gender: _gender.storageKey,
      );

      onStart?.call();
      await _audioPlayer.play(BytesSource(audio));

      final completer = Completer<void>();
      _playbackCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {},
      );
      onComplete?.call();
    } catch (_) {
      _tts.setStartHandler(() => onStart?.call());
      _tts.setCompletionHandler(() => onComplete?.call());
      _tts.setErrorHandler((_) => onComplete?.call());
      await _tts.speak(text);
    } finally {
      await _playbackCompleteSub?.cancel();
      _playbackCompleteSub = null;
    }
  }

  String _previewText() {
    if (_engine == TtsEngine.cartesia) {
      return _gender == VoiceGender.male
          ? 'Cartesia male voice profile activated.'
          : 'Cartesia female voice profile activated.';
    }
    return _gender == VoiceGender.male
        ? 'Male voice profile activated.'
        : 'Female voice profile activated.';
  }

  Future<void> _initializeDeviceTts(VoiceGender gender) async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(gender == VoiceGender.male ? 0.92 : 1.02);
    await _tts.setVolume(1.0);
    await _applyDeviceVoice(gender);
  }

  String _prepareSpeechText(String text) {
    return text
        .replaceAll('\n', '. ')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _applyDeviceVoice(VoiceGender gender) async {
    final voices = await _tts.getVoices;
    if (voices is! List || voices.isEmpty) return;

    final parsedVoices = voices
        .whereType<Map>()
        .map((voice) => Map<String, dynamic>.from(voice))
        .where((voice) {
          final locale = (voice['locale'] ?? '').toString().toLowerCase();
          return locale.startsWith('en');
        })
        .toList();

    if (parsedVoices.isEmpty) return;

    final savedName = _prefs?.getString(
      gender == VoiceGender.male ? _maleVoiceKey : _femaleVoiceKey,
    );

    Map<String, dynamic>? selected;

    if (savedName != null) {
      for (final voice in parsedVoices) {
        if ((voice['name'] ?? '').toString() == savedName) {
          selected = voice;
          break;
        }
      }
    }

    selected ??= _pickBestVoice(parsedVoices, gender);
    if (selected == null) return;

    final voiceMap = {
      'name': selected['name'].toString(),
      'locale': selected['locale'].toString(),
    };

    await _tts.setVoice(voiceMap);

    await _prefs?.setString(
      gender == VoiceGender.male ? _maleVoiceKey : _femaleVoiceKey,
      voiceMap['name']!,
    );
  }

  Map<String, dynamic>? _pickBestVoice(
    List<Map<String, dynamic>> voices,
    VoiceGender gender,
  ) {
    final scored = voices.map((voice) {
      final name = (voice['name'] ?? '').toString().toLowerCase();
      final genderTag = (voice['gender'] ?? '').toString().toLowerCase();
      var score = 0;

      final isFemale = genderTag.contains('female') ||
          name.contains('female') ||
          _containsAny(name, [
            'samantha',
            'victoria',
            'karen',
            'susan',
            'kate',
            'zira',
            'aria',
          ]);
      final isMale = genderTag.contains('male') ||
          name.contains('male') ||
          _containsAny(name, [
            'daniel',
            'fred',
            'aaron',
            'james',
            'david',
            'guy',
            'ryan',
          ]);

      if (gender == VoiceGender.female && isFemale) score += 100;
      if (gender == VoiceGender.male && isMale) score += 100;

      if (_containsAny(
        name,
        ['neural', 'enhanced', 'premium', 'wavenet', 'natural'],
      )) {
        score += 40;
      }
      if (_containsAny(name, ['local', 'on-device', 'embedded'])) score += 20;
      if (name.contains('network')) score -= 10;

      return MapEntry(voice, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    final best = scored.firstWhere(
      (entry) => entry.value >= 100,
      orElse: () => scored.first,
    );
    return best.key;
  }

  bool _containsAny(String value, List<String> terms) {
    return terms.any(value.contains);
  }
}

typedef VoidCallback = void Function();
