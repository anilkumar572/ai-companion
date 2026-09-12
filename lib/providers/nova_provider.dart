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
  bool _micPermissionGranted = false;
  bool _startingListen = false;
  bool _stoppingListen = false;
  int _busyListenRetries = 0;
  DateTime? _listenStartedAt;
  DateTime? _lastOrbTapAt;

  bool get isMicActive => _recorder.isRecording || _speech.isListening;

  Future<void> bootstrap() async {
    voiceGender = voiceGenderFromStorage(_prefs.getString(NovaConstants.prefsVoiceGender));

    _micPermissionGranted = await _requestMicPermission();
    if (!_micPermissionGranted) {
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

  bool _isRapidOrbTap() {
    final now = DateTime.now();
    final lastTap = _lastOrbTapAt;
    _lastOrbTapAt = now;
    return lastTap != null && now.difference(lastTap) < const Duration(milliseconds: 450);
  }

  Future<void> startListening() async {
    if (!isBootstrapped || _startingListen || _stoppingListen) return;
    if (_isRapidOrbTap()) return;
    if (state == NovaAgentState.listening ||
        state == NovaAgentState.speaking ||
        state == NovaAgentState.thinking) {
      return;
    }

    _startingListen = true;
    _busyListenRetries = 0;
    try {
      if (!_micPermissionGranted) {
        _micPermissionGranted = await _requestMicPermission();
      }
      if (!_micPermissionGranted) {
        _setRecoverableError(
          'Microphone permission is required. Enable it in Settings.',
        );
        return;
      }

      errorMessage = null;
      _clearConversationDisplay();
      audioLevel = 0;

      if (isMicActive) {
        await _stopCapture();
      }

      await _startCommandListening();
    } finally {
      _startingListen = false;
    }
  }

  Future<void> stopListening() async {
    if (_stoppingListen) return;
    if (state != NovaAgentState.listening) {
      await _stopCapture();
      audioLevel = 0;
      return;
    }

    _stoppingListen = true;
    _commandCaptureActive = false;
    _listenStartedAt = null;
    state = NovaAgentState.thinking;
    statusMessage = 'Understanding what you said…';
    notifyListeners();

    try {
      final transcript = await _finishCapture();
      audioLevel = 0;

      if (transcript.isNotEmpty) {
        await _beginProcessing(transcript);
        return;
      }

      await _returnToIdleWithHint(
        _usingRecorder && !_workerRestSttAvailable
            ? 'Cloud speech is unavailable. Tap the orb and try again.'
            : 'I did not catch that. Tap the orb, speak clearly, then tap again.',
      );
    } finally {
      _stoppingListen = false;
    }
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
    await _returnToIdleWithHint(
      'Could not start listening. Check microphone permission and try again.',
    );
  }

  Future<void> _startDeviceSpeechListening() async {
    _usingRecorder = false;

    if (!_commandCaptureActive || state != NovaAgentState.listening) return;

    try {
      await _speech.startListening(
        onResult: (transcript, isFinal) {
          if (!_commandCaptureActive ||
              _processingTranscript ||
              _stoppingListen) {
            return;
          }

          if (transcript.trim().isNotEmpty) {
            liveTranscript = transcript;
            notifyListeners();
          }
          // Manual tap-to-talk: only stopListening() submits the transcript.
        },
        onSoundLevel: _updateAudioLevel,
        localeId: preferredLanguage,
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 30),
      );
    } catch (error) {
      _commandCaptureActive = false;
      _listenStartedAt = null;

      final message = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'Could not start listening. Tap the orb to try again.';
      await _returnToIdleWithHint(message);
    }
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
    if (_stoppingListen) return;

    if (_isBenignSpeechError(message)) {
      return;
    }

    if (message.contains('busy') &&
        _busyListenRetries < 1 &&
        _commandCaptureActive) {
      _busyListenRetries++;
      unawaited(_retryDeviceSpeechAfterBusy());
      return;
    }

    _commandCaptureActive = false;
    unawaited(_recorder.cancel());
    unawaited(
      _returnToIdleWithHint(
        message.isEmpty
            ? 'Speech recognition failed. Tap the orb to try again.'
            : message,
      ),
    );
  }

  bool _isBenignSpeechError(String message) {
    return message.contains('did not catch that') ||
        message == 'error_speech_timeout' ||
        message == 'error_no_match';
  }

  Future<void> _retryDeviceSpeechAfterBusy() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!_commandCaptureActive || state != NovaAgentState.listening) return;

    await _speech.shutdown(hardwareCooldown: true);
    await _startDeviceSpeechListening();
  }

  void _handleSpeechStatus(String status) {
    // Tap-to-talk only — never auto-submit when the speech engine pauses or stops.
    if (_usingRecorder) return;
    if (status != 'done' && status != 'notListening') return;
    if (!_commandCaptureActive || state != NovaAgentState.listening) return;
    if (_stoppingListen || _processingTranscript) return;
    if (_isWithinListenGracePeriod()) return;

    // Engine timed out while waiting for the user tap — keep transcript, stay listening.
    if (liveTranscript.trim().isNotEmpty && !_speech.isListening) {
      statusMessage = 'Still listening — tap the orb when you are done';
      notifyListeners();
    }
  }

  bool _isWithinListenGracePeriod() {
    final startedAt = _listenStartedAt;
    if (startedAt == null) return false;
    return DateTime.now().difference(startedAt) < const Duration(seconds: 2);
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
    _busyListenRetries = 0;
    errorMessage = null;
    liveTranscript = '';
    state = NovaAgentState.idle;
    statusMessage = 'Tap the orb to speak';
    notifyListeners();
  }

  Future<void> _returnToIdleWithHint(String message) async {
    await _stopCapture();
    _processingTranscript = false;
    _busyListenRetries = 0;
    _commandCaptureActive = false;
    _listenStartedAt = null;
    errorMessage = null;
    liveTranscript = '';
    audioLevel = 0;
    state = NovaAgentState.idle;
    statusMessage = message;
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
