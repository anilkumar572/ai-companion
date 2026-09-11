import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nova_state.dart';
import '../models/voice_gender.dart';
import '../services/calendar_service.dart';
import '../services/nova_agent.dart';
import '../services/reminder_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/web_search_service.dart';

class NovaProvider extends ChangeNotifier {
  factory NovaProvider({required SharedPreferences prefs}) {
    final reminders = ReminderService(prefs);
    final calendar = CalendarService();
    final webSearch = WebSearchService();
    return NovaProvider._(
      prefs: prefs,
      speech: SpeechService(),
      tts: TtsService(),
      agent: NovaAgent(
        reminders: reminders,
        calendar: calendar,
        webSearch: webSearch,
      ),
    );
  }

  NovaProvider._({
    required SharedPreferences prefs,
    required SpeechService speech,
    required TtsService tts,
    required NovaAgent agent,
  })  : _prefs = prefs,
        _speech = speech,
        _tts = tts,
        _agent = agent;

  final SharedPreferences _prefs;
  final SpeechService _speech;
  final TtsService _tts;
  final NovaAgent _agent;

  NovaAgentState state = NovaAgentState.idle;
  VoiceGender voiceGender = VoiceGender.female;
  String statusMessage = 'Tap the orb to speak with Nova.';
  String liveTranscript = '';
  String lastResponse = '';
  double audioLevel = 0.0;
  bool isBootstrapped = false;
  String? errorMessage;

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

    final speechReady = await _speech.initialize();
    await _tts.initialize(gender: voiceGender);

    if (!speechReady) {
      errorMessage = 'Speech recognition is unavailable on this device.';
      state = NovaAgentState.error;
    }

    isBootstrapped = true;
    notifyListeners();
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    voiceGender = gender;
    await _prefs.setString(NovaConstants.prefsVoiceGender, gender.storageKey);
    await _tts.setGender(gender);
    notifyListeners();
  }

  Future<void> startListening() async {
    if (state == NovaAgentState.listening || state == NovaAgentState.speaking) {
      return;
    }

    errorMessage = null;
    liveTranscript = '';
    state = NovaAgentState.listening;
    statusMessage = 'Listening…';
    notifyListeners();

    try {
      await _speech.startListening(
        onResult: (transcript, isFinal) {
          liveTranscript = transcript;
          notifyListeners();
          if (isFinal && transcript.trim().isNotEmpty) {
            _processTranscript(transcript);
          }
        },
        onSoundLevel: (level) {
          audioLevel = level.clamp(0.0, 1.0);
          notifyListeners();
        },
      );
    } catch (error) {
      _setError('Unable to start listening: $error');
    }
  }

  Future<void> stopListening() async {
    await _speech.stopListening();
    if (state == NovaAgentState.listening) {
      state = NovaAgentState.idle;
      statusMessage = 'Tap the orb to speak with Nova.';
      notifyListeners();
    }
  }

  Future<void> _processTranscript(String transcript) async {
    await _speech.stopListening();
    state = NovaAgentState.thinking;
    statusMessage = 'Processing your request…';
    notifyListeners();

    try {
      final response = await _agent.respond(transcript);
      lastResponse = response;
      state = NovaAgentState.speaking;
      statusMessage = 'Nova is responding…';
      notifyListeners();

      await _tts.speak(
        response,
        onComplete: () {
          state = NovaAgentState.idle;
          statusMessage = 'Tap the orb to speak with Nova.';
          audioLevel = 0;
          notifyListeners();
        },
      );
    } catch (error) {
      _setError('I encountered an error while processing your request.');
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    state = NovaAgentState.idle;
    statusMessage = 'Tap the orb to speak with Nova.';
    notifyListeners();
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _setError(String message) {
    errorMessage = message;
    state = NovaAgentState.error;
    statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }
}
