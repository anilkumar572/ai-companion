import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';

class ReminderService {
  ReminderService(this._prefs);

  final SharedPreferences _prefs;
  static const _storageKey = 'nova_reminders';
  final _uuid = const Uuid();

  List<NovaReminder> getAll() {
    final raw = _prefs.getStringList(_storageKey) ?? [];
    return raw
        .map((entry) {
          final data = jsonDecode(entry) as Map<String, dynamic>;
          return NovaReminder(
            id: data['id'] as String,
            title: data['title'] as String,
            scheduledAt: DateTime.parse(data['scheduledAt'] as String),
            completed: data['completed'] as bool? ?? false,
          );
        })
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  Future<NovaReminder> add(String title, DateTime scheduledAt) async {
    final reminder = NovaReminder(
      id: _uuid.v4(),
      title: title,
      scheduledAt: scheduledAt,
    );
    final items = getAll();
    items.add(reminder);
    await _save(items);
    return reminder;
  }

  Future<void> complete(String id) async {
    final items = getAll()
        .map((item) => item.id == id ? item.copyWith(completed: true) : item)
        .toList();
    await _save(items);
  }

  List<NovaReminder> upcoming({int limit = 5}) {
    final now = DateTime.now();
    return getAll()
        .where((item) => !item.completed && item.scheduledAt.isAfter(now))
        .take(limit)
        .toList();
  }

  Future<void> _save(List<NovaReminder> items) async {
    final encoded = items
        .map(
          (item) => jsonEncode({
            'id': item.id,
            'title': item.title,
            'scheduledAt': item.scheduledAt.toIso8601String(),
            'completed': item.completed,
          }),
        )
        .toList();
    await _prefs.setStringList(_storageKey, encoded);
  }
}
