enum TtsEngine {
  device,
  cartesia;

  String get label => switch (this) {
        TtsEngine.device => 'Device',
        TtsEngine.cartesia => 'Cartesia',
      };

  String get storageKey => name;

  static TtsEngine fromStorage(String? value) {
    return TtsEngine.values.firstWhere(
      (engine) => engine.storageKey == value,
      orElse: () => TtsEngine.device,
    );
  }
}
