import 'voice_gender.dart';

class AgentResult {
  const AgentResult({
    required this.message,
    this.voiceGenderChange,
  });

  final String message;
  final VoiceGender? voiceGenderChange;
}
