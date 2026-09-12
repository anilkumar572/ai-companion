import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.voiceCommunication,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );
    await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
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

    final audio = await _cartesia.synthesize(
      workerBaseUrl: workerUrl,
      installationId: installationId,
      text: prepared,
      language: languageOverride ?? preferredLanguage,
      gender: _gender.storageKey,
    );

    final completer = Completer<void>();
    final completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    final stateSub = _audioPlayer.onPlayerStateChanged.listen((playerState) {
      if (playerState == PlayerState.completed && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      onStart?.call();
      await _audioPlayer.play(
        BytesSource(audio, mimeType: 'audio/wav'),
      );
      await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException('Voice playback timed out');
        },
      );
      onComplete?.call();
    } finally {
      await completeSub.cancel();
      await stateSub.cancel();
    }
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

typedef VoidCallback = void Function();
