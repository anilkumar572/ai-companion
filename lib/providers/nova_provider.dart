import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/nova_state.dart';
import '../models/operation_mode.dart';
import '../models/tts_engine.dart';
import '../models/voice_gender.dart';
import '../services/calendar_service.dart';
import '../services/camera_service.dart';
import '../services/connectivity_service.dart';
import '../services/contacts_service.dart';
import '../services/conversation_service.dart';
import '../services/nova_agent.dart';
import '../services/phone_service.dart';
import '../services/reminder_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/web_search_service.dart';
import '../services/worker_stt_service.dart';
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
    ConnectivityService? connectivity,
    WorkerSttService? workerStt,
  })  : _prefs = prefs,
        _speech = speech,
        _tts = tts,
        _conversation = conversation,
        _connectivity = connectivity ?? ConnectivityService(),
        _workerStt = workerStt ?? WorkerSttService();

  final SharedPreferences _prefs;
  final SpeechService _speech;
  final TtsService _tts;
  final ConversationService _conversation;
  final ConnectivityService _connectivity;
  final WorkerSttService _workerStt;

  NovaAgentState state = NovaAgentState.idle;
  VoiceGender voiceGender = VoiceGender.female;
  TtsEngine ttsEngine = TtsEngine.device;
  OperationMode operationMode = OperationMode.auto;
  bool isOnlineActive = false;
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
  bool _processingWorkerStt = false;
  Timer? _sttCaptureTimer;

  Future<void> bootstrap() async {
    voiceGender = voiceGenderFromStorage(_prefs.getString(NovaConstants.prefsVoiceGender));
    operationMode = OperationMode.fromStorage(
      _prefs.getString(NovaConstants.prefsOperationMode),
    );
    _conversation.setLocalModelPath(_prefs.getString(NovaConstants.prefsLocalModelPath));

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
    ttsEngine = _tts.engine;
    isOnlineActive = await _resolveOnlineMode();

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

  String get workerUrl => NovaConstants.workerUrl;
  String get preferredLanguage => _tts.preferredLanguage;
  String get installationId => _tts.installationId;
  String get localModelPath => _prefs.getString(NovaConstants.prefsLocalModelPath) ?? '';

  Future<void> setOperationMode(OperationMode mode) async {
    operationMode = mode;
    await _prefs.setString(NovaConstants.prefsOperationMode, mode.storageKey);
    isOnlineActive = await _resolveOnlineMode();
    await _applyModeDefaults();
    notifyListeners();
  }

  Future<void> setPreferredLanguage(String language) async {
    await _tts.setPreferredLanguage(language);
    notifyListeners();
  }

  Future<void> updateLocalModelPath(String? path) async {
    final cleaned = path?.trim() ?? '';
    if (cleaned.isEmpty) {
      await _prefs.remove(NovaConstants.prefsLocalModelPath);
    } else {
      await _prefs.setString(NovaConstants.prefsLocalModelPath, cleaned);
    }
    _conversation.setLocalModelPath(cleaned.isEmpty ? null : cleaned);
    notifyListeners();
  }

  Future<void> setTtsEngine(TtsEngine engine) async {
    if (ttsEngine == engine) {
      await _tts.setEngine(engine, preview: true);
      return;
    }

    ttsEngine = engine;
    await _tts.setEngine(engine, preview: true);
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
    await _workerStt.stopCapture();
    _wakeWordEnabled = false;
    wakeWordListening = false;
    _awaitingCommand = false;

    errorMessage = null;
    liveTranscript = '';
    state = NovaAgentState.listening;
    statusMessage = '> manual uplink active — speak now';
    notifyListeners();

    try {
      if (isOnlineActive) {
        unawaited(_startWorkerSttCapture());
        return;
      }

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
    _sttCaptureTimer?.cancel();
    if (_workerStt.isCapturing) {
      await _finishWorkerSttCapture();
      return;
    }

    await _speech.stopListening();
    if (state == NovaAgentState.listening) {
      await _startWakeWordListening();
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _startWakeWordListening();
  }

  Future<bool> _resolveOnlineMode() async {
    switch (operationMode) {
      case OperationMode.online:
        return true;
      case OperationMode.offline:
        return false;
      case OperationMode.auto:
        return await _connectivity.hasInternet();
    }
  }

  Future<void> _applyModeDefaults() async {
    if (isOnlineActive) {
      if (ttsEngine != TtsEngine.cartesia) {
        ttsEngine = TtsEngine.cartesia;
        await _tts.setEngine(TtsEngine.cartesia);
      }
      return;
    }

    if (ttsEngine != TtsEngine.device) {
      ttsEngine = TtsEngine.device;
      await _tts.setEngine(TtsEngine.device);
    }
  }

  Future<void> _startWorkerSttCapture() async {
    _sttCaptureTimer?.cancel();
    await _speech.stopListening();

    state = NovaAgentState.listening;
    statusMessage = '> sarvam capture active — speak now';
    notifyListeners();

    try {
      await _workerStt.startCapture();
      statusMessage = '> recording for sarvam stt...';
      notifyListeners();

      _sttCaptureTimer = Timer(const Duration(seconds: 12), () {
        unawaited(_finishWorkerSttCapture());
      });
    } catch (error) {
      await _handleOnlineSttFailure('Could not start Sarvam capture: $error');
    }
  }

  Future<void> _finishWorkerSttCapture() async {
    if (_processingWorkerStt) return;
    _sttCaptureTimer?.cancel();

    if (!_workerStt.isCapturing) {
      if (state == NovaAgentState.listening) {
        await _startWakeWordListening();
      }
      return;
    }

    state = NovaAgentState.thinking;
    statusMessage = '> sarvam stt processing...';
    notifyListeners();

    try {
      final transcript = await _workerStt.stopAndTranscribe(
        workerBaseUrl: workerUrl,
        installationId: installationId,
        languageCode: NovaConstants.defaultSttLanguage,
      );
      liveTranscript = transcript;
      notifyListeners();
      _processingWorkerStt = true;
      await _processTranscript(transcript);
    } catch (error) {
      await _handleOnlineSttFailure('Sarvam STT failed: $error');
    }
  }

  Future<void> _handleOnlineSttFailure(String message) async {
    await _workerStt.stopCapture();
    _processingWorkerStt = false;
    statusMessage = '> stt fallback :: using device speech';
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
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        onDevice: true,
      );
    } catch (_) {
      _setRecoverableError(message);
      await _startWakeWordListening();
    }
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

    isOnlineActive = await _resolveOnlineMode();
    await _applyModeDefaults();
    _processingWorkerStt = false;

    _wakeWordEnabled = true;
    _awaitingCommand = false;
    wakeWordListening = true;
    state = NovaAgentState.idle;
    statusMessage = isOnlineActive
        ? '> online mode :: listening for wake word "${NovaConstants.wakeWord}"...'
        : '> offline mode :: listening for wake word "${NovaConstants.wakeWord}"...';
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
      statusMessage = isOnlineActive
          ? '> nova online — sarvam capture listening'
          : '> nova offline — awaiting command';
      notifyListeners();
      unawaited(() async {
        await _speech.stopListening();
        await _beginCommandCapture();
      }());
    }
  }

  Future<void> _beginCommandCapture() async {
    if (isOnlineActive) {
      await _startWorkerSttCapture();
      return;
    }

    await _speech.startListening(
      onResult: _handleWakeWordResult,
      onSoundLevel: _updateAudioLevel,
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      onDevice: true,
    );
  }

  void _updateAudioLevel(double level) {
    audioLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> _processTranscript(String transcript) async {
    _sttCaptureTimer?.cancel();
    await _speech.stopListening();
    await _workerStt.stopCapture();
    _wakeWordEnabled = false;
    wakeWordListening = false;
    _awaitingCommand = false;

    state = NovaAgentState.thinking;
    statusMessage = isOnlineActive
        ? '> cloud brain processing...'
        : '> local brain processing...';
    notifyListeners();

    try {
      isOnlineActive = await _resolveOnlineMode();
      await _applyModeDefaults();

      final result = await _conversation.respond(
        input: transcript,
        online: isOnlineActive,
        workerBaseUrl: workerUrl,
        installationId: installationId,
        language: isOnlineActive ? preferredLanguage : 'auto',
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
      statusMessage = '> transmitting response...';
      notifyListeners();

      await _tts.speak(
        result.message,
        onComplete: () async {
          _processingWorkerStt = false;
          await _startWakeWordListening();
        },
        languageOverride: isOnlineActive ? preferredLanguage : null,
      );
    } catch (error) {
      _processingWorkerStt = false;
      _setError('I encountered an error while processing your request.');
      await _startWakeWordListening();
    }
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _setError(String message) {
    _setRecoverableError(message);
  }

  void _setRecoverableError(String message) {
    errorMessage = message;
    state = NovaAgentState.error;
    statusMessage = '> fault :: $message';
    wakeWordListening = false;
    _processingWorkerStt = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _wakeWordEnabled = false;
    _sttCaptureTimer?.cancel();
    _speech.dispose();
    _workerStt.dispose();
    _tts.dispose();
    super.dispose();
  }
}
