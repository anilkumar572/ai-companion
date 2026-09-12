import 'voice_gender.dart';

class AgentResult {
  const AgentResult({
    required this.message,
    this.voiceGenderChange,
    this.mediaPath,
    this.isVideo = false,
    this.deferToCloud = false,
  });

  final String message;
  final VoiceGender? voiceGenderChange;
  final String? mediaPath;
  final bool isVideo;
  final bool deferToCloud;

  static const cloudDeferral = AgentResult(
    message: '',
    deferToCloud: true,
  );
}
