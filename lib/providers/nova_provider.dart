import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nova_state.dart';
import '../models/voice_gender.dart';
import '../services/calendar_service.dart';
import '../services/camera_service.dart';
import '../services/contacts_service.dart';
import '../services/conversation_service.dart';
import '../services/nova_agent.dart';
import '../services/phone_service.dart';
import '../services/reminder_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/web_search_service.dart';

class NovaProvider extends ChangeNotifier {
  factory NovaProvider({required SharedPreferences prefs}) {
    final reminders = ReminderService(prefs);
    final calendar = CalendarService();
    final webSearch = WebSearchService();
    final camera = CameraService();
    final contacts = ContactsService();
    final phone = PhoneService();
    final speech = SpeechService();
    final agent = NovaAgent(
      reminders: reminders,
      calendar: calendar,
      webSearch: webSearch,
      camera: camera,
      contacts: contacts,
      phone: phone,
    );
    return NovaProvider._(
      prefs: prefs,
      speech: speech,
      tts: TtsService(prefs: prefs),
      conversation: ConversationService(deviceAgent: agent),
    );
  }

  NovaProvider._({
    required SharedPreferences prefs,
    required SpeechService speech,
    required TtsService tts,
    required ConversationService conversation,
  })  : _prefs = prefs,
        _speech = speech,
        _tts = tts,
        _conversation = conversation;

  final SharedPreferences _prefs;
  final SpeechService _speech;
  final TtsService _tts;
  final ConversationService _conversation;

  NovaAgentState state = NovaAgentState.idle;
  VoiceGender voiceGender = VoiceGender.female;
  String statusMessage = 'Starting Nova…';
  String liveTranscript = '';
  String lastResponse = '';
  String? lastMediaPath;
  bool lastMediaIsVideo = false;
  double audioLevel = 0.0;
  bool isBootstrapped = false;
  String? errorMessage;

  bool _commandCaptureActive = false;
  bool _processingTranscript = false;

  bool get isMicActive => _speech.isListening;

  Future<void> bootstrap() async {
    voiceGender = voiceGenderFromStorage(_prefs.getString(NovaConstants.prefsVoiceGender));

    final micGranted = await _requestMicPermission();
    if (!micGranted) {
      errorMessage = 'Microphone permission is required for voice interaction.';
      state = NovaAgentState.error;
      isBootstrapped = true;
      notifyListeners();
      return;
    }

    final speechReady = await _speech.initialize(
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
    );
    await _tts.initialize(gender: voiceGender);

    if (!speechReady) {
      errorMessage = 'Speech recognition is unavailable on this device.';
      state = NovaAgentState.error;
      isBootstrapped = true;
      notifyListeners();
      return;
    }

    isBootstrapped = true;
    await _enterIdle();
  }

  String get workerUrl => NovaConstants.workerUrl;
  String get preferredLanguage => _tts.preferredLanguage;
  String get installationId => _tts.installationId;

  Future<void> setPreferredLanguage(String language) async {
    await _tts.setPreferredLanguage(language);
    notifyListeners();
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    await _speech.shutdown();
    if (voiceGender == gender) {
      await _tts.setGender(gender, preview: true);
      return;
    }

    voiceGender = gender;
    await _prefs.setString(NovaConstants.prefsVoiceGender, gender.storageKey);
    await _tts.setGender(gender, preview: true);
    notifyListeners();
  }

  Future<void> startListening() async {
    if (state == NovaAgentState.listening ||
        state == NovaAgentState.speaking ||
        state == NovaAgentState.thinking) {
      return;
    }

    await _speech.shutdown();
    errorMessage = null;
    liveTranscript = '';
    audioLevel = 0;

    await _startCommandListening();
  }

  Future<void> stopListening() async {
    if (state != NovaAgentState.listening) {
      await _speech.shutdown();
      audioLevel = 0;
      return;
    }

    _commandCaptureActive = false;
    final transcript = liveTranscript.trim();
    await _speech.shutdown();
    audioLevel = 0;

    if (transcript.isNotEmpty) {
      await _beginProcessing(transcript);
      return;
    }

    await _enterIdle();
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _enterIdle();
  }

  Future<void> releaseMicrophone() async {
    _commandCaptureActive = false;
    await _speech.shutdown();
    audioLevel = 0;

    if (state == NovaAgentState.listening) {
      await _enterIdle();
    }
  }

  Future<void> _startCommandListening() async {
    _commandCaptureActive = true;
    state = NovaAgentState.listening;
    statusMessage = 'Listening… tap the orb when done';
    notifyListeners();

    try {
      await _speech.startListening(
        onResult: (transcript, isFinal) {
          if (!_commandCaptureActive || _processingTranscript) return;

          liveTranscript = transcript;
          notifyListeners();

          if (!isFinal || transcript.trim().isEmpty) return;

          _commandCaptureActive = false;
          unawaited(_beginProcessing(transcript.trim()));
        },
        onSoundLevel: _updateAudioLevel,
        localeId: _speechLocaleId,
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 2),
        onDevice: true,
      );
    } catch (_) {
      _commandCaptureActive = false;
      _setRecoverableError('Could not start listening. Tap the orb to try again.');
    }
  }

  String get _speechLocaleId => preferredLanguage.replaceAll('-', '_');

  void _handleSpeechError(String message) {
    if (state != NovaAgentState.listening || _processingTranscript) return;
    _commandCaptureActive = false;
    unawaited(_speech.shutdown());
    _setRecoverableError(
      message.isEmpty
          ? 'Speech recognition failed. Tap the orb to try again.'
          : message,
    );
  }

  void _handleSpeechStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    if (_speech.isListening || _processingTranscript) return;
    if (!_commandCaptureActive || state != NovaAgentState.listening) return;

    _commandCaptureActive = false;
    final transcript = liveTranscript.trim();

    if (transcript.isNotEmpty) {
      unawaited(_beginProcessing(transcript));
      return;
    }

    unawaited(_enterIdle());
  }

  Future<void> _beginProcessing(String transcript) async {
    if (_processingTranscript) return;
    _processingTranscript = true;
    _commandCaptureActive = false;

    // Stop mic FIRST so TTS can take audio focus.
    await _speech.shutdown();
    audioLevel = 0;
    errorMessage = null;
    liveTranscript = transcript;

    state = NovaAgentState.thinking;
    statusMessage = 'Thinking…';
    notifyListeners();

    try {
      final result = await _conversation.respond(
        input: transcript,
        workerBaseUrl: workerUrl,
        installationId: installationId,
        language: preferredLanguage,
      );

      if (result.voiceGenderChange != null &&
          result.voiceGenderChange != voiceGender) {
        voiceGender = result.voiceGenderChange!;
        await _prefs.setString(
          NovaConstants.prefsVoiceGender,
          voiceGender.storageKey,
        );
        await _tts.setGender(voiceGender);
      }

      lastResponse = result.message;
      lastMediaPath = result.mediaPath;
      lastMediaIsVideo = result.isVideo;
      state = NovaAgentState.speaking;
      statusMessage = 'Speaking…';
      notifyListeners();

      // Mic is already off — safe to play voice reply.
      await _tts.speak(
        result.message,
        onComplete: () async {
          _processingTranscript = false;
          await _enterIdle();
        },
        languageOverride: preferredLanguage,
      );
    } catch (_) {
      _processingTranscript = false;
      _setRecoverableError('Voice playback failed. Tap the orb to try again.');
    }
  }

  Future<void> _enterIdle() async {
    await _speech.shutdown();
    _processingTranscript = false;
    _commandCaptureActive = false;
    errorMessage = null;
    audioLevel = 0;
    liveTranscript = '';
    state = NovaAgentState.idle;
    statusMessage = 'Tap the orb to speak';
    notifyListeners();
  }

  void _updateAudioLevel(double level) {
    if (state != NovaAgentState.listening || !_commandCaptureActive) return;
    audioLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _setRecoverableError(String message) {
    errorMessage = message;
    state = NovaAgentState.error;
    statusMessage = message;
    _processingTranscript = false;
    _commandCaptureActive = false;
    audioLevel = 0;
    unawaited(_speech.shutdown());
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.dispose();
    _tts.dispose();
    super.dispose();
  }
}
