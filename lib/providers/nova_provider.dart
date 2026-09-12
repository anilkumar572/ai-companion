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
    _enterIdle();
    notifyListeners();
  }

  String get workerUrl => NovaConstants.workerUrl;
  String get preferredLanguage => _tts.preferredLanguage;
  String get installationId => _tts.installationId;

  Future<void> setPreferredLanguage(String language) async {
    await _tts.setPreferredLanguage(language);
    notifyListeners();
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
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

    await _speech.stopListening();
    errorMessage = null;
    liveTranscript = '';

    await _startCommandListening(
      statusMessage: 'Listening… tap the orb when done',
    );
  }

  Future<void> stopListening() async {
    await _speech.stopListening();
    _commandCaptureActive = false;

    if (state == NovaAgentState.listening) {
      final transcript = liveTranscript.trim();
      if (transcript.isNotEmpty) {
        await _processTranscript(transcript);
        return;
      }
      _enterIdle();
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _enterIdle();
  }

  Future<void> _startCommandListening({
    required String statusMessage,
  }) async {
    _commandCaptureActive = true;
    state = NovaAgentState.listening;
    this.statusMessage = statusMessage;
    notifyListeners();

    await _speech.startListening(
      onResult: (transcript, isFinal) {
        liveTranscript = transcript;
        notifyListeners();
        if (isFinal && transcript.trim().isNotEmpty && !_processingTranscript) {
          _commandCaptureActive = false;
          unawaited(_processTranscript(transcript.trim()));
        }
      },
      onSoundLevel: _updateAudioLevel,
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      onDevice: false,
    );
  }

  void _handleSpeechStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    if (_speech.isListening) return;

    if (!_commandCaptureActive || state != NovaAgentState.listening) return;

    _commandCaptureActive = false;
    final transcript = liveTranscript.trim();
    if (transcript.isNotEmpty && !_processingTranscript) {
      unawaited(_processTranscript(transcript));
      return;
    }

    liveTranscript = '';
    _enterIdle();
  }

  void _enterIdle() {
    unawaited(_speech.stopListening());
    _processingTranscript = false;
    _commandCaptureActive = false;
    errorMessage = null;
    audioLevel = 0;
    state = NovaAgentState.idle;
    statusMessage = 'Tap the orb to speak';
    notifyListeners();
  }

  void _updateAudioLevel(double level) {
    audioLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> _processTranscript(String transcript) async {
    if (_processingTranscript) return;
    _processingTranscript = true;

    await _speech.stopListening();
    _commandCaptureActive = false;
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

      await _tts.speak(
        result.message,
        onComplete: () {
          _processingTranscript = false;
          _enterIdle();
        },
        languageOverride: preferredLanguage,
      );
    } catch (error) {
      _processingTranscript = false;
      _setRecoverableError('Voice playback failed. Please try again.');
    }
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
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.dispose();
    _tts.dispose();
    super.dispose();
  }
}
