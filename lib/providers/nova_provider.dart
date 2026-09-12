import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/agent_result.dart';
import '../models/nova_state.dart';
import '../models/voice_gender.dart';
import '../services/audio_recording_service.dart';
import '../services/cartesia_tts_service.dart';
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
import '../services/worker_health_service.dart';
import '../services/worker_stt_service.dart';

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
      recorder: AudioRecordingService(),
      workerStt: const WorkerSttService(),
      workerHealth: const WorkerHealthService(),
      tts: TtsService(prefs: prefs),
      conversation: ConversationService(deviceAgent: agent),
    );
  }

  NovaProvider._({
    required SharedPreferences prefs,
    required SpeechService speech,
    required AudioRecordingService recorder,
    required WorkerSttService workerStt,
    required WorkerHealthService workerHealth,
    required TtsService tts,
    required ConversationService conversation,
  })  : _prefs = prefs,
        _speech = speech,
        _recorder = recorder,
        _workerStt = workerStt,
        _workerHealth = workerHealth,
        _tts = tts,
        _conversation = conversation;

  final SharedPreferences _prefs;
  final SpeechService _speech;
  final AudioRecordingService _recorder;
  final WorkerSttService _workerStt;
  final WorkerHealthService _workerHealth;
  final TtsService _tts;
  final ConversationService _conversation;

  NovaAgentState state = NovaAgentState.idle;
  VoiceGender voiceGender = VoiceGender.female;
  String statusMessage = 'Starting ${NovaConstants.appName}…';
  String liveTranscript = '';
  String lastResponse = '';
  String? lastMediaPath;
  bool lastMediaIsVideo = false;
  double audioLevel = 0.0;
  bool isBootstrapped = false;
  String? errorMessage;

  bool _commandCaptureActive = false;
  bool _processingTranscript = false;
  bool _usingRecorder = false;
  bool _workerRestSttAvailable = false;
  bool _startingListen = false;
  DateTime? _listenStartedAt;

  bool get isMicActive => _recorder.isRecording || _speech.isListening;

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
      _workerRestSttAvailable = await _workerHealth.supportsRestStt(workerUrl);
      if (!_workerRestSttAvailable) {
        errorMessage =
            'Speech recognition is unavailable on this device right now.';
        state = NovaAgentState.error;
        isBootstrapped = true;
        notifyListeners();
        return;
      }
    } else {
      unawaited(_refreshWorkerSttAvailability());
    }

    isBootstrapped = true;
    await _enterIdle();
  }

  Future<void> _refreshWorkerSttAvailability() async {
    _workerRestSttAvailable = await _workerHealth.supportsRestStt(workerUrl);
  }

  String get workerUrl => NovaConstants.workerUrl;
  String get preferredLanguage => _tts.preferredLanguage;
  String get installationId => _tts.installationId;

  Future<void> setPreferredLanguage(String language) async {
    await _tts.setPreferredLanguage(language);
    notifyListeners();
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    await _stopCapture();
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
    if (!isBootstrapped || _startingListen) return;
    if (state == NovaAgentState.listening ||
        state == NovaAgentState.speaking ||
        state == NovaAgentState.thinking) {
      return;
    }

    _startingListen = true;
    try {
      final micGranted = await _requestMicPermission();
      if (!micGranted) {
        _setRecoverableError(
          'Microphone permission is required. Enable it in Settings.',
        );
        return;
      }

      if (isMicActive) {
        await _stopCapture();
      } else {
        _commandCaptureActive = false;
        _listenStartedAt = null;
        audioLevel = 0;
      }

      errorMessage = null;
      _clearConversationDisplay();
      await _startCommandListening();
    } finally {
      _startingListen = false;
    }
  }

  Future<void> stopListening() async {
    if (state != NovaAgentState.listening) {
      await _stopCapture();
      audioLevel = 0;
      return;
    }

    _commandCaptureActive = false;
    _listenStartedAt = null;
    state = NovaAgentState.thinking;
    statusMessage = 'Understanding what you said…';
    notifyListeners();

    final transcript = await _finishCapture();
    audioLevel = 0;

    if (transcript.isNotEmpty) {
      await _beginProcessing(transcript);
      return;
    }

    _setRecoverableError(
      _usingRecorder && !_workerRestSttAvailable
          ? 'Cloud speech is unavailable. Teju will use your phone microphone next time — tap the orb and try again.'
          : 'I did not catch that. Tap the orb, speak clearly, then tap again.',
    );
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _enterIdle();
  }

  Future<void> releaseMicrophone() async {
    _commandCaptureActive = false;
    _listenStartedAt = null;
    await _stopCapture();
    audioLevel = 0;

    if (state == NovaAgentState.listening) {
      await _enterIdle();
    }
  }

  void _clearConversationDisplay() {
    liveTranscript = '';
    lastResponse = '';
    lastMediaPath = null;
    lastMediaIsVideo = false;
  }

  Future<void> _startCommandListening() async {
    _commandCaptureActive = true;
    _listenStartedAt = DateTime.now();
    state = NovaAgentState.listening;
    statusMessage = 'Listening… tap the orb when done';
    notifyListeners();

    if (_speech.isAvailable) {
      await _startDeviceSpeechListening();
      return;
    }

    if (_workerRestSttAvailable) {
      try {
        await _recorder.start(onAmplitude: _updateAudioLevel);
        _usingRecorder = true;
        return;
      } catch (_) {
        // Fall through to error below.
      }
    }

    _commandCaptureActive = false;
    _listenStartedAt = null;
    _setRecoverableError(
      'Could not start listening. Check microphone permission and try again.',
    );
  }

  Future<void> _startDeviceSpeechListening() async {
    _usingRecorder = false;

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!_commandCaptureActive || state != NovaAgentState.listening) return;
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 180 * attempt));
      }

      try {
        await _speech.startListening(
          onResult: (transcript, isFinal) {
            if (!_commandCaptureActive || _processingTranscript) return;

            if (transcript.trim().isNotEmpty) {
              liveTranscript = transcript;
              notifyListeners();
            }

            if (!isFinal || transcript.trim().isEmpty) return;

            _commandCaptureActive = false;
            unawaited(_beginProcessing(transcript.trim()));
          },
          onSoundLevel: _updateAudioLevel,
          localeId: preferredLanguage,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        );
        return;
      } catch (error) {
        lastError = error;
      }
    }

    _commandCaptureActive = false;
    _listenStartedAt = null;

    final message = lastError is StateError && lastError.message.isNotEmpty
        ? lastError.message
        : 'Could not start listening. Tap the orb to try again.';
    _setRecoverableError(message);
  }

  Future<String> _finishCapture() async {
    if (!_usingRecorder) {
      final deviceTranscript = liveTranscript.trim();
      await _speech.shutdown();
      return deviceTranscript;
    }

    final recordedFile = await _recorder.stop();
    await _speech.shutdown();
    if (recordedFile == null) {
      return '';
    }

    try {
      return await _workerStt.transcribe(
        workerBaseUrl: workerUrl,
        installationId: installationId,
        audioFile: recordedFile,
        languageCode: preferredLanguage,
      );
    } on WorkerSttException catch (error) {
      if (error.statusCode == 404) {
        _workerRestSttAvailable = false;
      }
      return '';
    } catch (_) {
      return '';
    } finally {
      if (await recordedFile.exists()) {
        await recordedFile.delete();
      }
    }
  }

  Future<void> _stopCapture() async {
    _commandCaptureActive = false;
    _listenStartedAt = null;
    await _recorder.cancel();
    await _speech.shutdown();
    audioLevel = 0;
  }

  void _handleSpeechError(String message) {
    if (_usingRecorder) return;
    if (state != NovaAgentState.listening || _processingTranscript) return;
    if (_isWithinListenGracePeriod()) return;

    if (_isBenignSpeechError(message)) {
      return;
    }

    if (message.contains('busy') && _isWithinListenGracePeriod()) {
      unawaited(_retryDeviceSpeechListening());
      return;
    }

    _commandCaptureActive = false;
    unawaited(_recorder.cancel());
    _setRecoverableError(
      message.isEmpty
          ? 'Speech recognition failed. Tap the orb to try again.'
          : message,
    );
  }

  bool _isBenignSpeechError(String message) {
    return message.contains('did not catch that') ||
        message == 'error_speech_timeout' ||
        message == 'error_no_match';
  }

  void _handleSpeechStatus(String status) {
    if (_usingRecorder) return;
    if (!_commandCaptureActive || state != NovaAgentState.listening) return;
    if (_processingTranscript) return;
    if (status != 'done' && status != 'notListening') return;
    if (_isWithinListenGracePeriod()) return;
    if (_speech.isListening) return;

    final transcript = liveTranscript.trim();
    if (transcript.isEmpty) return;

    _commandCaptureActive = false;
    unawaited(_beginProcessing(transcript));
  }

  bool _isWithinListenGracePeriod() {
    final startedAt = _listenStartedAt;
    if (startedAt == null) return false;
    return DateTime.now().difference(startedAt) < const Duration(seconds: 2);
  }

  Future<void> _retryDeviceSpeechListening() async {
    if (!_commandCaptureActive || state != NovaAgentState.listening) return;
    await _speech.shutdown(hardwareCooldown: true);
    await _startDeviceSpeechListening();
  }

  Future<void> _beginProcessing(String transcript) async {
    if (_processingTranscript) return;
    _processingTranscript = true;
    _commandCaptureActive = false;
    _listenStartedAt = null;

    await _stopCapture();
    errorMessage = null;
    lastResponse = '';
    lastMediaPath = null;
    lastMediaIsVideo = false;
    liveTranscript = transcript;

    state = NovaAgentState.thinking;
    statusMessage = 'Thinking…';
    notifyListeners();

    AgentResult? result;
    try {
      result = await _conversation.respond(
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
      statusMessage = 'Preparing voice…';
      notifyListeners();

      await _tts.speak(
        result.message,
        onStart: () {
          statusMessage = 'Speaking…';
          notifyListeners();
        },
        onComplete: () async {
          _processingTranscript = false;
          await _enterIdle();
        },
        languageOverride: result.speakLanguage ?? preferredLanguage,
      );
    } catch (error) {
      _processingTranscript = false;
      if (result != null && result.message.isNotEmpty) {
        lastResponse = result.message;
        lastMediaPath = result.mediaPath;
        lastMediaIsVideo = result.isVideo;
        state = NovaAgentState.idle;
        statusMessage =
            'Reply is shown above. Voice could not play — check media volume.';
        errorMessage = null;
        notifyListeners();
        return;
      }

      final message = switch (error) {
        CartesiaTtsException() =>
          'Voice synthesis failed. Check your internet connection and try again.',
        TtsPlaybackException() =>
          'Voice playback failed. Check your phone volume and try again.',
        _ => 'Something went wrong while replying. Tap the orb to try again.',
      };
      _setRecoverableError(message);
    }
  }

  Future<void> _enterIdle() async {
    await _stopCapture();
    _processingTranscript = false;
    errorMessage = null;
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
    final recorderGranted = await _recorder.hasPermission();
    if (recorderGranted) return true;

    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _setRecoverableError(String message) {
    errorMessage = message;
    state = NovaAgentState.error;
    statusMessage = message;
    _processingTranscript = false;
    _commandCaptureActive = false;
    _listenStartedAt = null;
    audioLevel = 0;
    unawaited(_stopCapture());
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.dispose();
    _recorder.dispose();
    _tts.dispose();
    super.dispose();
  }
}
