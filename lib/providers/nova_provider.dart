import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
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
      recorder: AudioRecordingService(),
      workerStt: const WorkerSttService(),
      tts: TtsService(prefs: prefs),
      conversation: ConversationService(deviceAgent: agent),
    );
  }

  NovaProvider._({
    required SharedPreferences prefs,
    required SpeechService speech,
    required AudioRecordingService recorder,
    required WorkerSttService workerStt,
    required TtsService tts,
    required ConversationService conversation,
  })  : _prefs = prefs,
        _speech = speech,
        _recorder = recorder,
        _workerStt = workerStt,
        _tts = tts,
        _conversation = conversation;

  final SharedPreferences _prefs;
  final SpeechService _speech;
  final AudioRecordingService _recorder;
  final WorkerSttService _workerStt;
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
  bool _usingRecorder = true;
  bool _wakeWordEnabled = true;
  bool _wakeWordListenActive = false;
  bool _promotingToCommand = false;
  DateTime? _listenStartedAt;

  bool get isMicActive =>
      _recorder.isRecording || _speech.isListening || _wakeWordListenActive;
  bool get wakeWordEnabled => _wakeWordEnabled;
  bool get wakeWordListening =>
      _wakeWordEnabled && _wakeWordListenActive && state == NovaAgentState.idle;

  Future<void> bootstrap() async {
    voiceGender = voiceGenderFromStorage(_prefs.getString(NovaConstants.prefsVoiceGender));
    _wakeWordEnabled = _prefs.getBool(NovaConstants.prefsWakeWordEnabled) ?? true;

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
      _usingRecorder = true;
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

  Future<void> setWakeWordEnabled(bool enabled) async {
    _wakeWordEnabled = enabled;
    await _prefs.setBool(NovaConstants.prefsWakeWordEnabled, enabled);
    if (!enabled) {
      await _stopWakeWordListening();
      if (state == NovaAgentState.idle) {
        statusMessage = 'Tap the orb to speak';
        notifyListeners();
      }
      return;
    }

    if (state == NovaAgentState.idle) {
      statusMessage = 'Say ${WakeWordDetector.wakeWordHint()} to speak';
      notifyListeners();
      unawaited(_startWakeWordListening());
    }
  }

  Future<void> resumeWakeWordIfNeeded() async {
    if (!_wakeWordEnabled || state != NovaAgentState.idle || _processingTranscript) {
      return;
    }
    if (_wakeWordListenActive || _commandCaptureActive) return;
    await _startWakeWordListening();
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    await _stopWakeWordListening();
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
    if (state == NovaAgentState.listening ||
        state == NovaAgentState.speaking ||
        state == NovaAgentState.thinking) {
      return;
    }

    await _stopWakeWordListening();

    final micGranted = await _requestMicPermission();
    if (!micGranted) {
      _setRecoverableError(
        'Microphone permission is required. Enable it in Settings.',
      );
      return;
    }

    await _stopCapture();
    errorMessage = null;
    _clearConversationDisplay();
    audioLevel = 0;

    await _startCommandListening(afterWakeWord: false);
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
      'I did not catch that. Tap the orb, speak clearly, then tap again.',
    );
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    await _enterIdle();
  }

  Future<void> releaseMicrophone() async {
    _commandCaptureActive = false;
    _listenStartedAt = null;
    await _stopWakeWordListening();
    await _stopCapture();
    audioLevel = 0;

    if (state == NovaAgentState.listening) {
      await _enterIdle();
    }
  }

  Future<void> _startWakeWordListening() async {
    if (!_wakeWordEnabled ||
        state != NovaAgentState.idle ||
        _processingTranscript ||
        _commandCaptureActive ||
        !_speech.isAvailable) {
      return;
    }

    if (_wakeWordListenActive || _speech.isListening || _recorder.isRecording) {
      return;
    }

    _wakeWordListenActive = true;
    statusMessage = 'Say ${WakeWordDetector.wakeWordHint()} to speak';
    notifyListeners();

    try {
      await _speech.startListening(
        onResult: _handleWakeWordResult,
        onSoundLevel: _updateWakeWordAudioLevel,
        localeId: preferredLanguage,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 2),
      );
    } catch (_) {
      _wakeWordListenActive = false;
      statusMessage = 'Tap the orb to speak';
      notifyListeners();
    }
  }

  Future<void> _stopWakeWordListening() async {
    if (!_wakeWordListenActive) return;
    _wakeWordListenActive = false;
    if (!_commandCaptureActive && !_processingTranscript) {
      await _speech.shutdown();
    }
    if (state == NovaAgentState.idle) {
      audioLevel = 0;
    }
  }

  void _handleWakeWordResult(String transcript, bool isFinal) {
    if (!_wakeWordListenActive || state != NovaAgentState.idle) return;
    if (!WakeWordDetector.containsWakeWord(transcript)) return;

    if (!WakeWordDetector.shouldProcess(transcript, isFinal)) return;

    final command = WakeWordDetector.extractCommand(transcript);
    _wakeWordListenActive = false;
    _promotingToCommand = true;
    _clearConversationDisplay();

    if (command.isNotEmpty) {
      liveTranscript = command;
      notifyListeners();
      unawaited(_handoffAfterWakeWord(() => _beginProcessing(command)));
      return;
    }

    unawaited(_handoffAfterWakeWord(_promoteToCommandListening));
  }

  Future<void> _handoffAfterWakeWord(Future<void> Function() next) async {
    try {
      await _speech.shutdown();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await next();
    } finally {
      _promotingToCommand = false;
    }
  }

  Future<void> _promoteToCommandListening() async {
    audioLevel = 0;
    liveTranscript = '';
    await _startCommandListening(afterWakeWord: true);
  }

  void _clearConversationDisplay() {
    liveTranscript = '';
    lastResponse = '';
    lastMediaPath = null;
    lastMediaIsVideo = false;
  }

  void _updateWakeWordAudioLevel(double level) {
    if (!_wakeWordListenActive || state != NovaAgentState.idle) return;
    audioLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  Future<void> _restartWakeWordListeningSoon() async {
    if (!_wakeWordEnabled || state != NovaAgentState.idle) return;
    if (_promotingToCommand || _commandCaptureActive) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (state == NovaAgentState.idle &&
        !_commandCaptureActive &&
        !_promotingToCommand) {
      await _startWakeWordListening();
    }
  }

  Future<void> _startCommandListening({required bool afterWakeWord}) async {
    _commandCaptureActive = true;
    _listenStartedAt = DateTime.now();
    state = NovaAgentState.listening;
    statusMessage = afterWakeWord
        ? 'Listening for your command…'
        : 'Listening… tap the orb when done';
    notifyListeners();

    if (afterWakeWord) {
      await _startDeviceSpeechListening(
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
      );
      return;
    }

    try {
      await _recorder.start(onAmplitude: _updateAudioLevel);
      _usingRecorder = true;
    } catch (_) {
      await _startDeviceSpeechListening();
    }
  }

  Future<void> _startDeviceSpeechListening({
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    _usingRecorder = false;
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
        listenFor: listenFor,
        pauseFor: pauseFor,
      );
    } catch (error) {
      _commandCaptureActive = false;
      _listenStartedAt = null;

      final message = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'Could not start listening. Tap the orb to try again.';
      _setRecoverableError(message);
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
    if (_wakeWordListenActive && state == NovaAgentState.idle) {
      _wakeWordListenActive = false;
      if (_isBenignSpeechError(message)) {
        unawaited(_restartWakeWordListeningSoon());
        return;
      }
      unawaited(_restartWakeWordListeningSoon());
      return;
    }

    if (_usingRecorder) return;
    if (state != NovaAgentState.listening || _processingTranscript) return;
    if (_isWithinListenGracePeriod()) return;

    if (_isBenignSpeechError(message)) {
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
    if (_wakeWordListenActive && state == NovaAgentState.idle) {
      if (status == 'done' || status == 'notListening') {
        _wakeWordListenActive = false;
        if (!_promotingToCommand && !_commandCaptureActive) {
          unawaited(_restartWakeWordListeningSoon());
        }
      }
      return;
    }

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
    return DateTime.now().difference(startedAt) < const Duration(seconds: 1);
  }

  Future<void> _beginProcessing(String transcript) async {
    if (_processingTranscript) return;
    _processingTranscript = true;
    _commandCaptureActive = false;
    _listenStartedAt = null;

    await _stopWakeWordListening();
    await _stopCapture();
    errorMessage = null;
    lastResponse = '';
    lastMediaPath = null;
    lastMediaIsVideo = false;
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
        onComplete: () async {
          _processingTranscript = false;
          await _enterIdle();
        },
        languageOverride: preferredLanguage,
      );
    } catch (error) {
      _processingTranscript = false;
      if (lastResponse.isNotEmpty) {
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
    statusMessage = _wakeWordEnabled
        ? 'Say ${WakeWordDetector.wakeWordHint()} to speak'
        : 'Tap the orb to speak';
    notifyListeners();

    if (_wakeWordEnabled) {
      unawaited(_startWakeWordListening());
    }
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
    unawaited(_stopWakeWordListening());
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
