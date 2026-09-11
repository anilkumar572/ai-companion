import 'package:intl/intl.dart';

import '../core/constants.dart';
import 'calendar_service.dart';
import 'reminder_service.dart';
import 'web_search_service.dart';

class NovaAgent {
  NovaAgent({
    required ReminderService reminders,
    required CalendarService calendar,
    required WebSearchService webSearch,
  })  : _reminders = reminders,
        _calendar = calendar,
        _webSearch = webSearch;

  final ReminderService _reminders;
  final CalendarService _calendar;
  final WebSearchService _webSearch;

  Future<String> respond(String input) async {
    final text = input.trim();
    if (text.isEmpty) {
      return 'I did not receive any input. Please speak again when you are ready.';
    }

    final normalized = text.toLowerCase();

    if (_containsAny(normalized, ['hello', 'hi nova', 'good morning', 'good evening'])) {
      return _greeting();
    }

    if (_containsAny(normalized, ['who are you', 'what are you', 'your name'])) {
      return 'I am ${NovaConstants.appName}, your formal voice companion. I am prepared to assist with reminders, calendar summaries, and web search.';
    }

    if (_containsAny(normalized, ['calendar', 'schedule', 'appointment', 'meeting today'])) {
      return _calendar.summarizeToday();
    }

    if (_containsAny(normalized, ['remind me', 'set a reminder', 'reminder'])) {
      return _handleReminder(text);
    }

    if (_containsAny(normalized, ['my reminders', 'upcoming reminders', 'list reminders'])) {
      return _listReminders();
    }

    if (_containsAny(normalized, ['search', 'look up', 'find online', 'web search'])) {
      final query = _extractAfterKeywords(
        text,
        ['search for', 'look up', 'find online', 'web search for', 'search'],
      );
      if (query.isEmpty) {
        return 'Please specify what you would like me to search for.';
      }
      final result = await _webSearch.search(query);
      return result;
    }

    if (_containsAny(normalized, ['time', 'what time'])) {
      final now = DateTime.now();
      final formatter = DateFormat('h:mm a, EEEE, MMMM d');
      return 'The current time is ${formatter.format(now)}.';
    }

    return 'Understood. I am configured for voice assistance with reminders, calendar review, and web search. Please state a specific command, such as "Nova, what is on my calendar today?" or "Nova, remind me to call the client at 3 PM."';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$salutation. ${NovaConstants.appName} is online and ready to assist you.';
  }

  String _listReminders() {
    final items = _reminders.upcoming();
    if (items.isEmpty) {
      return 'You have no upcoming reminders.';
    }

    final formatter = DateFormat('MMM d, h:mm a');
    final lines = items
        .map((item) => '${formatter.format(item.scheduledAt)} — ${item.title}')
        .join('\n');
    return 'Your upcoming reminders are:\n$lines';
  }

  Future<String> _handleReminder(String text) async {
    final lower = text.toLowerCase();
    final atIndex = lower.indexOf(' at ');
    if (atIndex == -1) {
      return 'To set a reminder, say "Remind me to" followed by your task and time, for example: "Remind me to submit the report at 5 PM."';
    }

    final remindIndex = lower.indexOf('remind me to');
    final taskStart = remindIndex == -1 ? 0 : remindIndex + 'remind me to'.length;
    final taskPart = text.substring(taskStart, atIndex).trim();
    final timePart = text.substring(atIndex + 4).trim();

    if (taskPart.isEmpty || timePart.isEmpty) {
      return 'I could not parse the reminder. Please repeat the task and time clearly.';
    }

    final scheduledAt = _parseTime(timePart);
    if (scheduledAt == null) {
      return 'I could not understand the time "$timePart". Please use a clear time such as 3 PM or 15:30.';
    }

    await _reminders.add(taskPart, scheduledAt);
    final formatter = DateFormat('h:mm a on EEEE, MMMM d');
    return 'Reminder recorded. I will remind you to $taskPart at ${formatter.format(scheduledAt)}.';
  }

  DateTime? _parseTime(String raw) {
    final cleaned = raw.replaceAll('.', '').trim();
    final meridiemMatch = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (meridiemMatch != null) {
      var hour = int.parse(meridiemMatch.group(1)!);
      final minute = int.parse(meridiemMatch.group(2) ?? '0');
      final meridiem = meridiemMatch.group(3)!.toLowerCase();

      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;

      return _nextOccurrence(hour, minute);
    }

    final formats = [
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
      DateFormat('h:mm a'),
      DateFormat.jm(),
    ];

    for (final format in formats) {
      try {
        final parsed = format.parse(cleaned);
        return _nextOccurrence(parsed.hour, parsed.minute);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  DateTime _nextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  String _extractAfterKeywords(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    for (final keyword in keywords) {
      final index = lower.indexOf(keyword);
      if (index != -1) {
        return text.substring(index + keyword.length).trim();
      }
    }
    return text.trim();
  }

  bool _containsAny(String text, List<String> terms) {
    return terms.any(text.contains);
  }
}
