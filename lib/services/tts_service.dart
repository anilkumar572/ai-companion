import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../models/voice_gender.dart';

class TtsService {
  TtsService() : _tts = FlutterTts();

  final FlutterTts _tts;
  VoiceGender _gender = VoiceGender.female;
  bool _initialized = false;

  Future<void> initialize({VoiceGender gender = VoiceGender.female}) async {
    _gender = gender;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _applyVoice(gender);
    _initialized = true;
  }

  Future<void> setGender(VoiceGender gender) async {
    _gender = gender;
    if (_initialized) {
      await _applyVoice(gender);
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
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();

  Future<void> _applyVoice(VoiceGender gender) async {
    final voices = await _tts.getVoices;
    if (voices is! List) return;

    final englishVoices = voices
        .whereType<Map>()
        .map((voice) => Map<String, String>.from(voice))
        .where((voice) => (voice['locale'] ?? '').toString().startsWith('en'))
        .toList();

    if (englishVoices.isEmpty) return;

    Map<String, String>? selected;

    for (final voice in englishVoices) {
      final name = (voice['name'] ?? '').toLowerCase();
      final genderTag = (voice['gender'] ?? '').toLowerCase();

      final isFemale = genderTag.contains('female') ||
          name.contains('female') ||
          name.contains('samantha') ||
          name.contains('victoria') ||
          name.contains('karen') ||
          name.contains('susan');

      final isMale = genderTag.contains('male') ||
          name.contains('male') ||
          name.contains('daniel') ||
          name.contains('fred') ||
          name.contains('aaron') ||
          name.contains('james');

      if (gender == VoiceGender.female && isFemale) {
        selected = voice;
        break;
      }
      if (gender == VoiceGender.male && isMale) {
        selected = voice;
        break;
      }
    }

    selected ??= englishVoices.first;
    await _tts.setVoice(selected);
  }
}

typedef VoidCallback = void Function();
