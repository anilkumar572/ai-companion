enum OperationMode {
  auto,
  online,
  offline;

  String get label => switch (this) {
        OperationMode.auto => 'Auto',
        OperationMode.online => 'Online',
        OperationMode.offline => 'Offline',
      };

  String get storageKey => name;

  static OperationMode fromStorage(String? value) {
    return OperationMode.values.firstWhere(
      (mode) => mode.storageKey == value,
      orElse: () => OperationMode.auto,
    );
  }
}
