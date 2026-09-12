import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
  })  : _prefs = prefs,
        _cartesia = cartesia ?? const CartesiaTtsService();

  final CartesiaTtsService _cartesia;
  final SharedPreferences? _prefs;

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
    await _configurePlaybackAudio();
    _initialized = true;
  }

  Future<void> _configurePlaybackAudio() async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.duckOthers,
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ),
    );
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

    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _configurePlaybackAudio();

    final audio = await _cartesia.synthesize(
      workerBaseUrl: workerUrl,
      installationId: installationId,
      text: prepared,
      language: languageOverride ?? preferredLanguage,
      gender: _gender.storageKey,
    );

    onStart?.call();

    final tempPath = await _writeTempWav(audio);
    try {
      await _playFile(tempPath);
      onComplete?.call();
    } finally {
      unawaited(File(tempPath).delete());
    }
  }

  Future<void> _playFile(String path) async {
    final player = AudioPlayer();
    try {
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);

      await player.setSource(DeviceFileSource(path, mimeType: 'audio/wav'));
      await player.resume();

      await _waitForPlayback(player);
    } finally {
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  Future<void> _waitForPlayback(AudioPlayer player) async {
    Duration? totalDuration;
    final durationSub = player.onDurationChanged.listen((duration) {
      totalDuration = duration;
    });

    try {
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (DateTime.now().isBefore(deadline)) {
        final state = player.state;
        if (state == PlayerState.completed) {
          return;
        }

        final position = await player.getCurrentPosition();
        final duration = totalDuration ?? await player.getDuration();

        if (duration != null &&
            position != null &&
            duration.inMilliseconds > 0 &&
            position.inMilliseconds >= duration.inMilliseconds - 150) {
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      throw TimeoutException('Voice playback timed out');
    } finally {
      await durationSub.cancel();
    }
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

  Future<void> stop() async {}

  Future<void> dispose() async {}

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
