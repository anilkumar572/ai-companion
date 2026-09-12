import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/voice_gender.dart';
import 'cartesia_tts_service.dart';

class TtsService {
  TtsService({
    SharedPreferences? prefs,
    CartesiaTtsService? cartesia,
    FlutterTts? deviceTts,
  })  : _prefs = prefs,
        _cartesia = cartesia ?? const CartesiaTtsService(),
        _deviceTts = deviceTts ?? FlutterTts();

  final CartesiaTtsService _cartesia;
  final FlutterTts _deviceTts;
  final SharedPreferences? _prefs;
  AudioPlayer? _player;

  VoiceGender _gender = VoiceGender.female;
  bool _initialized = false;

  String get workerUrl => NovaConstants.workerUrl;

  String get preferredLanguage =>
      _prefs?.getString(NovaConstants.prefsPreferredLanguage) ??
      NovaConstants.defaultLanguage;

  String get installationId {
    final saved = _prefs?.getString(NovaConstants.prefsInstallationId);
    if (saved != null && saved.isNotEmpty) return saved;
    final generated = const Uuid().v4();
    unawaited(_prefs?.setString(NovaConstants.prefsInstallationId, generated));
    return generated;
  }

  Future<void> initialize({VoiceGender gender = VoiceGender.female}) async {
    _gender = gender;
    await _configureDeviceTts();
    _initialized = true;
  }

  Future<void> _configureDeviceTts() async {
    await _deviceTts.setVolume(1.0);
    await _deviceTts.setSpeechRate(0.48);
    await _deviceTts.setPitch(_gender == VoiceGender.male ? 0.85 : 1.0);
    await _deviceTts.awaitSpeakCompletion(true);
    await _setDeviceLanguage(preferredLanguage);
  }

  Future<void> setPreferredLanguage(String language) async {
    await _prefs?.setString(
      NovaConstants.prefsPreferredLanguage,
      language.trim(),
    );
    await _setDeviceLanguage(language);
  }

  Future<void> setGender(VoiceGender gender, {bool preview = false}) async {
    _gender = gender;
    if (!_initialized) {
      await initialize(gender: gender);
    } else {
      await _deviceTts.setPitch(gender == VoiceGender.male ? 0.85 : 1.0);
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

    final language = languageOverride ?? preferredLanguage;
    Uint8List? audio;

    try {
      audio = await _cartesia.synthesize(
        workerBaseUrl: workerUrl,
        installationId: installationId,
        text: prepared,
        language: language,
        gender: _gender.storageKey,
      );
    } on CartesiaTtsException {
      onStart?.call();
      await _speakWithDeviceTts(prepared, language);
      onComplete?.call();
      return;
    }

    final tempPath = await _writeTempWav(audio);
    try {
      final playedOnlineVoice = await _playCartesiaFile(
        tempPath,
        onStart: onStart,
      );
      if (!playedOnlineVoice) {
        onStart?.call();
        await _speakWithDeviceTts(prepared, language);
      }
      onComplete?.call();
    } finally {
      unawaited(File(tempPath).delete());
    }
  }

  Future<bool> _playCartesiaFile(
    String path, {
    VoidCallback? onStart,
  }) async {
    final player = _player ??= AudioPlayer();
    try {
      await player.stop();
      await player.setFilePath(path);
      await player.setVolume(1.0);
      onStart?.call();
      await player.play();

      if (!await _waitUntilAudible(player)) {
        await player.stop();
        return false;
      }

      await player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitUntilAudible(AudioPlayer player) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      if (player.playing && player.position > const Duration(milliseconds: 40)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return player.playing;
  }

  Future<void> _speakWithDeviceTts(String text, String language) async {
    await _setDeviceLanguage(language);
    await _deviceTts.setPitch(_gender == VoiceGender.male ? 0.85 : 1.0);
    await _deviceTts.stop();
    final result = await _deviceTts.speak(text);
    if (result != 1) {
      throw TtsPlaybackException('Device voice playback failed.');
    }
  }

  Future<void> _setDeviceLanguage(String language) async {
    final normalized = language.replaceAll('_', '-');
    final locales = await _deviceTts.getLanguages;
    if (locales is List) {
      for (final locale in locales) {
        if (locale is String &&
            locale.toLowerCase() == normalized.toLowerCase()) {
          await _deviceTts.setLanguage(locale);
          return;
        }
      }
    }
    await _deviceTts.setLanguage(normalized);
  }

  Future<String> _writeTempWav(Uint8List audio) async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/nova_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
    final file = File(path);
    await file.writeAsBytes(audio, flush: true);
    if (!await file.exists() || await file.length() < 44) {
      throw TtsPlaybackException('Voice audio file could not be prepared.');
    }
    return path;
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    await _deviceTts.stop();
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }

  String _previewText() {
    return _gender == VoiceGender.male
        ? 'Male voice profile activated.'
        : 'Female voice profile activated.';
  }

  String _prepareSpeechText(String text) {
    return text
        .replaceAll('\n', '. ')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class TtsPlaybackException implements Exception {
  TtsPlaybackException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

typedef VoidCallback = void Function();
