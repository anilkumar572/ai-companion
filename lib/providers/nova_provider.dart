import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nova_state.dart';
import '../models/voice_gender.dart';
import '../services/calendar_service.dart';
import '../services/camera_service.dart';
import '../services/contacts_service.dart';
import '../services/nova_agent.dart';
import '../services/phone_service.dart';
import '../services/reminder_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/web_search_service.dart';
import '../utils/wake_word_detector.dart';

class NovaProvider extends ChangeNotifier {
  factory NovaProvider({required SharedPreferences prefs}) {
    final reminders = ReminderService(prefs);
    final calendar = CalendarService();
    final webSearch = WebSearchService();
    final camera = CameraService();
    final contacts = ContactsService();
    final phone = PhoneService();
    final speech = SpeechService();
    return NovaProvider._(
      prefs: prefs,
      speech: speech,
      tts: TtsService(prefs: prefs),
      agent: NovaAgent(
        reminders: reminders,
        calendar: calendar,
        webSearch: webSearch,
        camera: camera,
        contacts: contacts,
        phone: phone,
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
  String statusMessage = '> initializing neural link...';
  String liveTranscript = '';
  String lastResponse = '';
  String? lastMediaPath;
  bool lastMediaIsVideo = false;
  double audioLevel = 0.0;
  bool isBootstrapped = false;
  bool wakeWordListening = false;
  String? errorMessage;

  bool _wakeWordEnabled = true;
  bool _awaitingCommand = false;
  bool _restartingWakeWord = false;

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
    await _startWakeWordListening();
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
    _wakeWordEnabled = false;
    wakeWordListening = false;
    _awaitingCommand = false;

    errorMessage = null;
    liveTranscript = '';
    state = NovaAgentState.listening;
    statusMessage = '> manual uplink active — speak now';
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
        onSoundLevel: _updateAudioLevel,
      );
    } catch (error) {
      _setError('Unable to start listening: $error');
    }
  }

  Future<void> stopListening() async {
    await _speech.stopListening();
    if (state == NovaAgentState.listening) {
      await _startWakeWordListening();
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _startWakeWordListening();
  }

  void _handleSpeechStatus(String status) {
    if (!_wakeWordEnabled || _restartingWakeWord) return;
    if (state != NovaAgentState.idle) return;

    if (status == 'done' || status == 'notListening') {
      if (wakeWordListening && !_speech.isListening) {
        _restartWakeWordSession();
      }
    }
  }

  Future<void> _restartWakeWordSession() async {
    if (_restartingWakeWord || !_wakeWordEnabled) return;
    if (state != NovaAgentState.idle) return;

    _restartingWakeWord = true;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _restartingWakeWord = false;

    if (_wakeWordEnabled && state == NovaAgentState.idle) {
      await _startWakeWordListening();
    }
  }

  Future<void> _startWakeWordListening() async {
    if (!_speech.isAvailable) return;

    _wakeWordEnabled = true;
    _awaitingCommand = false;
    wakeWordListening = true;
    state = NovaAgentState.idle;
    statusMessage = '> listening for wake word "${NovaConstants.wakeWord}"...';
    audioLevel = 0;
    notifyListeners();

    try {
      await _speech.startWakeWordListening(
        onResult: _handleWakeWordResult,
        onSoundLevel: _updateAudioLevel,
      );
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await _restartWakeWordSession();
    }
  }

  void _handleWakeWordResult(String transcript, bool isFinal) {
    if (!_wakeWordEnabled || state != NovaAgentState.idle) return;

    liveTranscript = transcript;
    notifyListeners();

    if (_awaitingCommand) {
      if (isFinal && transcript.trim().isNotEmpty) {
        _wakeWordEnabled = false;
        wakeWordListening = false;
        _awaitingCommand = false;
        _processTranscript(transcript);
      }
      return;
    }

    if (!WakeWordDetector.containsWakeWord(transcript)) return;

    final command = WakeWordDetector.extractCommand(transcript);
    if (WakeWordDetector.shouldProcess(transcript, isFinal) && command.isNotEmpty) {
      _wakeWordEnabled = false;
      wakeWordListening = false;
      _speech.stopListening();
      liveTranscript = command;
      notifyListeners();
      _processTranscript(command);
      return;
    }

    if (isFinal && command.isEmpty) {
      _awaitingCommand = true;
      wakeWordListening = false;
      state = NovaAgentState.listening;
      statusMessage = '> nova online — awaiting command';
      notifyListeners();
      _speech.stopListening();
      _speech.startListening(
        onResult: _handleWakeWordResult,
        onSoundLevel: _updateAudioLevel,
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _updateAudioLevel(double level) {
    audioLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> _processTranscript(String transcript) async {
    await _speech.stopListening();
    _wakeWordEnabled = false;
    wakeWordListening = false;
    _awaitingCommand = false;

    state = NovaAgentState.thinking;
    statusMessage = '> processing payload...';
    notifyListeners();

    try {
      final result = await _agent.respond(transcript);

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
      statusMessage = '> transmitting response...';
      notifyListeners();

      await _tts.speak(
        result.message,
        onComplete: () async {
          await _startWakeWordListening();
        },
      );
    } catch (error) {
      _setError('I encountered an error while processing your request.');
      await _startWakeWordListening();
    }
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _setError(String message) {
    errorMessage = message;
    state = NovaAgentState.error;
    statusMessage = '> fault :: $message';
    wakeWordListening = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _wakeWordEnabled = false;
    _speech.dispose();
    super.dispose();
  }
}
