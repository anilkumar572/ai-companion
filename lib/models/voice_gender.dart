enum VoiceGender {
  male,
  female,
}

extension VoiceGenderLabel on VoiceGender {
  String get label => switch (this) {
        VoiceGender.male => 'Male',
        VoiceGender.female => 'Female',
      };

  String get storageKey => name;
}

VoiceGender voiceGenderFromStorage(String? value) {
  return VoiceGender.values.firstWhere(
    (gender) => gender.name == value,
    orElse: () => VoiceGender.female,
  );
}
