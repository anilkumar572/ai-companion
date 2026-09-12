class NovaConstants {
  static const appName = 'Nova';
  static const tagline = '// NEURAL_LINK :: VOICE_INTERFACE :: ACTIVE';
  static const wakeWord = 'nova';

  static const prefsVoiceGender = 'voice_gender';
  static const prefsHasOnboarded = 'has_onboarded';

  static const prefsOperationMode = 'operation_mode';
  static const prefsSarvamApiKey = 'sarvam_api_key';
  static const prefsSarvamLanguage = 'sarvam_language';
  static const prefsSarvamModel = 'sarvam_model';
  static const prefsLocalModelPath = 'local_model_path';
  static const prefsTtsEngine = 'tts_engine';
  static const prefsInstallationId = 'installation_id';
  static const prefsCartesiaWorkerUrl = 'cartesia_worker_url';
  static const prefsCartesiaLanguage = 'cartesia_language';
  static const prefsCartesiaSpeed = 'cartesia_speed';
  static const prefsCartesiaFemaleVoiceId = 'cartesia_female_voice_id';
  static const prefsCartesiaMaleVoiceId = 'cartesia_male_voice_id';

  static const defaultCartesiaWorkerUrl =
      'https://buddy-ai-worker.anilgithubd.workers.dev';
  static const defaultSarvamLanguage = 'unknown';
  static const defaultSarvamModel = 'saaras:v3';
  static const defaultCartesiaLanguage = 'en-IN';
  static const defaultCartesiaFemaleVoiceId =
      'f786b574-daa5-4673-aa0c-cbe3e8534c02';
  static const defaultCartesiaMaleVoiceId = '';

  static const formalSystemPrompt = '''
You are Nova, a formal and precise voice companion.
Speak with clarity, respect, and brevity.
Address the user professionally.
Never use slang or casual filler words.
''';
}
