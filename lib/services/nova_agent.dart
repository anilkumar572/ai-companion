import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/agent_result.dart';
import '../models/voice_gender.dart';
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

  Future<AgentResult> respond(String input) async {
    final text = _cleanInput(input);
    if (text.isEmpty) {
      return const AgentResult(
        message:
            'I did not receive any input. Please speak again when you are ready.',
      );
    }

    final normalized = text.toLowerCase();

    final voiceChange = _detectVoiceChange(normalized);
    if (voiceChange != null) {
      return AgentResult(
        message: voiceChange.message,
        voiceGenderChange: voiceChange.gender,
      );
    }

    if (_containsAny(normalized, [
      'hello',
      'hi nova',
      'hey nova',
      'good morning',
      'good afternoon',
      'good evening',
    ])) {
      return AgentResult(message: _greeting());
    }

    if (_containsAny(normalized, [
      'who are you',
      'what are you',
      'your name',
      'introduce yourself',
    ])) {
      return AgentResult(
        message:
            'I am ${NovaConstants.appName}, your formal voice companion. I can answer questions, search the web, review your calendar, and manage reminders.',
      );
    }

    if (_containsAny(normalized, [
      'calendar',
      'schedule',
      'appointment',
      'meeting today',
      'events today',
      'what do i have today',
    ])) {
      return AgentResult(message: await _calendar.summarizeToday());
    }

    if (_containsAny(normalized, ['remind me', 'set a reminder', 'create reminder'])) {
      return AgentResult(message: await _handleReminder(text));
    }

    if (_containsAny(normalized, [
      'my reminders',
      'upcoming reminders',
      'list reminders',
      'show reminders',
    ])) {
      return AgentResult(message: _listReminders());
    }

    if (_containsAny(normalized, [
      'what time',
      'current time',
      'tell me the time',
    ])) {
      final now = DateTime.now();
      final formatter = DateFormat('h:mm a, EEEE, MMMM d');
      return AgentResult(message: 'The current time is ${formatter.format(now)}.');
    }

    if (_containsAny(normalized, [
      'what date',
      'today\'s date',
      'what day is it',
    ])) {
      final formatter = DateFormat('EEEE, MMMM d, yyyy');
      return AgentResult(
        message: 'Today is ${formatter.format(DateTime.now())}.',
      );
    }

    if (_looksLikeSearchCommand(normalized)) {
      final query = _extractSearchQuery(text, normalized);
      final result = await _webSearch.search(query);
      return AgentResult(message: result);
    }

    if (_looksLikeQuestion(normalized)) {
      final result = await _webSearch.search(text);
      return AgentResult(message: result);
    }

    final fallbackSearch = await _webSearch.search(text);
    if (!fallbackSearch.contains('could not find reliable information')) {
      return AgentResult(message: fallbackSearch);
    }

    return AgentResult(
      message:
          'I am ready to help. You may ask me a question, request a web search, set a reminder, or ask about your calendar.',
    );
  }

  String _cleanInput(String input) {
    final trimmed = input.trim();
    final greetingOnly = RegExp(
      r'^\s*(hey|hi|hello)\s+n[o0]va\s*[.!]?\s*$',
      caseSensitive: false,
    );
    if (greetingOnly.hasMatch(trimmed)) {
      return 'hello';
    }

    var text = trimmed.replaceFirst(
      RegExp(r'^\s*n[o0]va[,.!\s]+', caseSensitive: false),
      '',
    );
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  _VoiceChange? _detectVoiceChange(String normalized) {
    final wantsFemale = _containsAny(normalized, [
      'female voice',
      'woman voice',
      'use female',
      'switch to female',
      'change to female',
      'change voice to female',
    ]) ||
        RegExp(r'\bfemale\b').hasMatch(normalized);

    final wantsMale = !wantsFemale &&
        (_containsAny(normalized, [
              'male voice',
              'man voice',
              'use male',
              'switch to male',
              'change to male',
              'change voice to male',
            ]) ||
            RegExp(r'\bmale\b').hasMatch(normalized));

    if (wantsFemale) {
      return _VoiceChange(
        gender: VoiceGender.female,
        message: 'Voice profile updated. I will now speak with a female voice.',
      );
    }

    if (wantsMale) {
      return _VoiceChange(
        gender: VoiceGender.male,
        message: 'Voice profile updated. I will now speak with a male voice.',
      );
    }
    return null;
  }

  bool _looksLikeSearchCommand(String normalized) {
    return _containsAny(normalized, [
      'search for',
      'search about',
      'search ',
      'look up',
      'find online',
      'web search',
      'google ',
      'tell me about',
    ]);
  }

  bool _looksLikeQuestion(String normalized) {
    return normalized.startsWith('what ') ||
        normalized.startsWith('who ') ||
        normalized.startsWith('where ') ||
        normalized.startsWith('when ') ||
        normalized.startsWith('why ') ||
        normalized.startsWith('how ') ||
        normalized.startsWith('is ') ||
        normalized.startsWith('are ') ||
        normalized.startsWith('can ') ||
        normalized.contains('what is') ||
        normalized.contains('who is') ||
        normalized.contains('tell me');
  }

  String _extractSearchQuery(String text, String normalized) {
    const prefixes = [
      'search for',
      'search about',
      'look up',
      'find online',
      'web search for',
      'google',
      'tell me about',
      'search',
    ];

    for (final prefix in prefixes) {
      final index = normalized.indexOf(prefix);
      if (index != -1) {
        return text.substring(index + prefix.length).trim();
      }
    }
    return text.trim();
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

  bool _containsAny(String text, List<String> terms) {
    return terms.any(text.contains);
  }
}

class _VoiceChange {
  const _VoiceChange({
    required this.gender,
    required this.message,
  });

  final VoiceGender gender;
  final String message;
}
