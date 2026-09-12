class NovaReminder {
  const NovaReminder({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.completed = false,
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final bool completed;

  NovaReminder copyWith({
    bool? completed,
  }) {
    return NovaReminder(
      id: id,
      title: title,
      scheduledAt: scheduledAt,
      completed: completed ?? this.completed,
    );
  }
}
