class NovaConstants {
  static const appName = 'Teju';
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
You are Teju, a warm and helpful voice companion.
Speak in short, natural sentences that sound good when read aloud.
Use clear grammar and proper punctuation.
Never use bullet points, markdown, or overly formal jargon.
''';
}
