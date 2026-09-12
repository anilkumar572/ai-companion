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
    AudioPlayer? audioPlayer,
  })  : _prefs = prefs,
        _cartesia = cartesia ?? const CartesiaTtsService(),
        _audioPlayer = audioPlayer ?? AudioPlayer();

  final CartesiaTtsService _cartesia;
  final AudioPlayer _audioPlayer;
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
    await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    await _audioPlayer.setVolume(1.0);
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
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
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

    await stop();
    // Give Android time to release the microphone after recording.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await _configurePlaybackAudio();

    final audio = await _cartesia.synthesize(
      workerBaseUrl: workerUrl,
      installationId: installationId,
      text: prepared,
      language: languageOverride ?? preferredLanguage,
      gender: _gender.storageKey,
    );

    String? tempPath;
    try {
      final source = await _buildPlaybackSource(audio);
      if (source is DeviceFileSource) {
        tempPath = source.path;
      }

      onStart?.call();
      await _audioPlayer.play(source);
      await _audioPlayer.onPlayerComplete.first.timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw TimeoutException('Voice playback timed out'),
      );
      onComplete?.call();
    } on CartesiaTtsException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw TtsPlaybackException(
        'Could not play the voice reply on this device.',
        cause: error,
      );
    } finally {
      if (tempPath != null && tempPath.isNotEmpty) {
        unawaited(File(tempPath).delete());
      }
    }
  }

  Future<Source> _buildPlaybackSource(Uint8List audio) async {
    if (kIsWeb) {
      return BytesSource(audio, mimeType: 'audio/wav');
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/nova_tts_${DateTime.now().millisecondsSinceEpoch}.wav';
    final file = File(path);
    await file.writeAsBytes(audio, flush: true);
    return DeviceFileSource(path, mimeType: 'audio/wav');
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
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
