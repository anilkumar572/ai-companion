import 'dart:async';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/voice_gender.dart';

class TtsService {
  TtsService({SharedPreferences? prefs}) : _prefs = prefs, _tts = FlutterTts();

  final FlutterTts _tts;
  final SharedPreferences? _prefs;
  VoiceGender _gender = VoiceGender.female;
  bool _initialized = false;

  static const _femaleVoiceKey = 'tts_voice_female';
  static const _maleVoiceKey = 'tts_voice_male';

  Future<void> initialize({VoiceGender gender = VoiceGender.female}) async {
    _gender = gender;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(gender == VoiceGender.male ? 0.92 : 1.02);
    await _tts.setVolume(1.0);
    await _applyVoice(gender);
    _initialized = true;
  }

  Future<void> setGender(VoiceGender gender, {bool preview = false}) async {
    _gender = gender;
    if (!_initialized) {
      await initialize(gender: gender);
    } else {
      await _tts.setPitch(gender == VoiceGender.male ? 0.92 : 1.02);
      await _applyVoice(gender);
    }

    if (preview) {
      await speak(
        gender == VoiceGender.male
            ? 'Male voice profile activated.'
            : 'Female voice profile activated.',
      );
    }
  }

  Future<void> speak(
    String text, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) async {
    if (!_initialized) {
      await initialize(gender: _gender);
    }

    _tts.setStartHandler(() => onStart?.call());
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setErrorHandler((_) => onComplete?.call());

    await _tts.stop();
    await _tts.speak(_prepareSpeechText(text));
  }

  Future<void> stop() => _tts.stop();

  String _prepareSpeechText(String text) {
    return text
        .replaceAll('\n', '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _applyVoice(VoiceGender gender) async {
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
          _containsAny(name, ['samantha', 'victoria', 'karen', 'susan', 'kate', 'zira', 'aria']);
      final isMale = genderTag.contains('male') ||
          name.contains('male') ||
          _containsAny(name, ['daniel', 'fred', 'aaron', 'james', 'david', 'guy', 'ryan']);

      if (gender == VoiceGender.female && isFemale) score += 100;
      if (gender == VoiceGender.male && isMale) score += 100;

      if (_containsAny(name, ['neural', 'enhanced', 'premium', 'wavenet', 'natural'])) {
        score += 40;
      }
      if (_containsAny(name, ['local', 'on-device', 'embedded'])) score += 20;
      if (name.contains('network')) score -= 10;
      if (Platform.isIOS && name.contains('compact')) score += 5;

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
