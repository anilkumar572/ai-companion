class NovaConstants {
  static const appName = 'Nova';
  static const tagline = 'Your voice companion for calls, reminders, and everyday tasks';
  static const prefsVoiceGender = 'voice_gender';
  static const prefsHasOnboarded = 'has_onboarded';
  static const prefsInstallationId = 'installation_id';
  static const prefsPreferredLanguage = 'preferred_language';

  /// All cloud keys (Gemini, Sarvam, Cartesia) live on this worker.
  static const workerUrl = 'https://buddy-ai-worker.anilgithubd.workers.dev';
  static const defaultLanguage = 'en-IN';
  static const defaultSttLanguage = 'unknown';

  static const formalSystemPrompt = '''
You are Nova, a formal and precise voice companion.
Speak with clarity, respect, and brevity.
Address the user professionally.
Never use slang or casual filler words.
''';
}
