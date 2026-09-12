import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/agent_result.dart';
import '../models/voice_gender.dart';
import 'calendar_service.dart';
import 'camera_service.dart';
import 'contacts_service.dart';
import 'phone_service.dart';
import 'reminder_service.dart';
import 'web_search_service.dart';

class NovaAgent {
  NovaAgent({
    required ReminderService reminders,
    required CalendarService calendar,
    required WebSearchService webSearch,
    CameraService? camera,
    ContactsService? contacts,
    PhoneService? phone,
  })  : _reminders = reminders,
        _calendar = calendar,
        _webSearch = webSearch,
        _camera = camera ?? CameraService(),
        _contacts = contacts ?? ContactsService(),
        _phone = phone ?? PhoneService();

  final ReminderService _reminders;
  final CalendarService _calendar;
  final WebSearchService _webSearch;
  final CameraService _camera;
  final ContactsService _contacts;
  final PhoneService _phone;

  Future<AgentResult> respond(
    String input, {
    bool allowWebSearch = true,
    bool allowCloudDeferral = false,
  }) async {
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
            'I am ${NovaConstants.appName}, your formal on-device voice companion. I can call contacts, use the camera, manage reminders, review your calendar, and search the web.',
      );
    }

    if (_containsAny(normalized, [
      'what can you do',
      'your capabilities',
      'help me',
    ])) {
      return AgentResult(message: _capabilities());
    }

    if (_looksLikeCallCommand(normalized)) {
      return await _handleCall(text, normalized);
    }

    if (_containsAny(normalized, [
      'show contacts',
      'list contacts',
      'my contacts',
      'open contacts',
    ])) {
      return await _handleListContacts();
    }

    if (_containsAny(normalized, [
      'find contact',
      'search contact',
      'look up contact',
    ])) {
      final query = _extractAfterKeywords(
        text,
        ['find contact', 'search contact', 'look up contact'],
      );
      return await _handleFindContact(query);
    }

    if (_looksLikePhotoCommand(normalized)) {
      return await _handleTakePhoto();
    }

    if (_looksLikeVideoCommand(normalized)) {
      return await _handleRecordVideo();
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

    if (allowCloudDeferral &&
        (_looksLikeSearchCommand(normalized) || _looksLikeQuestion(normalized))) {
      return AgentResult.cloudDeferral;
    }

    if (allowWebSearch && _looksLikeSearchCommand(normalized)) {
      final query = _extractSearchQuery(text, normalized);
      final result = await _webSearch.search(query);
      return AgentResult(message: result);
    }

    if (allowWebSearch && _looksLikeQuestion(normalized)) {
      final result = await _webSearch.search(text);
      return AgentResult(message: result);
    }

    if (allowCloudDeferral) {
      return AgentResult.cloudDeferral;
    }

    if (allowWebSearch) {
      final fallbackSearch = await _webSearch.search(text);
      if (!fallbackSearch.contains('could not find reliable information')) {
        return AgentResult(message: fallbackSearch);
      }
    }

    return AgentResult(message: _capabilities());
  }

  String _capabilities() {
    return 'I can assist on-device with calls, contacts, camera photos, video recording, reminders, calendar review, and web search. For example, say "Call John", "Take a photo", or "What is on my calendar today?"';
  }

  Future<AgentResult> _handleCall(String text, String normalized) async {
    final name = _extractCallTarget(text, normalized);
    if (name.isEmpty) {
      return const AgentResult(
        message: 'Please tell me who you would like me to call.',
      );
    }

    if (RegExp(r'^\+?[\d\s\-()]{7,}$').hasMatch(name)) {
      try {
        await _phone.callNumber(name);
        return AgentResult(message: 'Calling $name now.');
      } on PhoneNumberException catch (error) {
        return AgentResult(message: error.message);
      } on PhoneLaunchException {
        return const AgentResult(
          message: 'I was unable to start the phone call on this device.',
        );
      }
    }

    try {
      final matches = await _contacts.searchByName(name);
      if (matches.isEmpty) {
        return AgentResult(
          message: 'I could not find a contact named "$name".',
        );
      }

      if (matches.length > 1) {
        final options = matches
            .take(3)
            .map((match) => match.displayName)
            .join(', ');
        return AgentResult(
          message:
              'I found multiple contacts: $options. Please say the full name you want to call.',
        );
      }

      final contact = matches.first;
      await _phone.callNumber(contact.phoneNumber);
      return AgentResult(
        message: 'Calling ${contact.displayName} now.',
      );
    } on ContactsPermissionException {
      return const AgentResult(
        message:
            'Contacts permission is required before I can place calls by name.',
      );
    } on PhoneLaunchException {
      return const AgentResult(
        message: 'I was unable to start the phone call on this device.',
      );
    }
  }

  Future<AgentResult> _handleListContacts() async {
    try {
      final contacts = await _contacts.listRecent(limit: 8);
      if (contacts.isEmpty) {
        return const AgentResult(message: 'No contacts were found on this device.');
      }

      final names = contacts.map((contact) => contact.displayName).join(', ');
      return AgentResult(message: 'Here are some of your contacts: $names.');
    } on ContactsPermissionException {
      return const AgentResult(
        message: 'Contacts permission is required to read your contacts.',
      );
    }
  }

  Future<AgentResult> _handleFindContact(String query) async {
    if (query.trim().isEmpty) {
      return const AgentResult(
        message: 'Please tell me the contact name you want to find.',
      );
    }

    try {
      final matches = await _contacts.searchByName(query);
      if (matches.isEmpty) {
        return AgentResult(message: 'No contact matched "$query".');
      }

      final lines = matches
          .take(5)
          .map((match) => '${match.displayName} — ${match.phoneNumber}')
          .join('\n');
      return AgentResult(message: 'Matching contacts:\n$lines');
    } on ContactsPermissionException {
      return const AgentResult(
        message: 'Contacts permission is required to search your contacts.',
      );
    }
  }

  Future<AgentResult> _handleTakePhoto() async {
    try {
      final capture = await _camera.takePhoto();
      if (capture == null) {
        return const AgentResult(message: 'The camera was closed before a photo was taken.');
      }

      return AgentResult(
        message: 'Photo captured successfully. It is ready for review on your device.',
        mediaPath: capture.path,
        isVideo: false,
      );
    } on CameraPermissionException {
      return const AgentResult(
        message: 'Camera permission is required before I can take a photo.',
      );
    }
  }

  Future<AgentResult> _handleRecordVideo() async {
    try {
      final capture = await _camera.recordVideo();
      if (capture == null) {
        return const AgentResult(message: 'Video recording was cancelled.');
      }

      return AgentResult(
        message: 'Video recorded successfully and saved on your device.',
        mediaPath: capture.path,
        isVideo: true,
      );
    } on CameraPermissionException {
      return const AgentResult(
        message: 'Camera permission is required before I can record video.',
      );
    }
  }

  bool _looksLikeCallCommand(String normalized) {
    if (normalized.startsWith('remind me')) return false;

    return normalized.startsWith('call ') ||
        normalized.startsWith('phone ') ||
        normalized.startsWith('dial ') ||
        normalized.startsWith('ring ') ||
        normalized.startsWith('make a call') ||
        normalized.contains('make a call to');
  }

  bool _looksLikePhotoCommand(String normalized) {
    return _containsAny(normalized, [
      'take a photo',
      'take photo',
      'take picture',
      'open camera',
      'capture photo',
      'capture image',
      'what am i looking at',
      'use camera',
    ]);
  }

  bool _looksLikeVideoCommand(String normalized) {
    return _containsAny(normalized, [
      'record video',
      'start video',
      'capture video',
      'film video',
      'shoot video',
    ]);
  }

  String _extractCallTarget(String text, String normalized) {
    const prefixes = ['call', 'phone', 'dial', 'ring'];
    for (final prefix in prefixes) {
      if (normalized.startsWith('$prefix ')) {
        return text.substring(prefix.length).trim();
      }
      final embedded = ' $prefix ';
      final index = normalized.indexOf(embedded);
      if (index != -1) {
        return text.substring(index + embedded.length).trim();
      }
    }

    final makeCall = normalized.indexOf('make a call to ');
    if (makeCall != -1) {
      return text.substring(makeCall + 'make a call to '.length).trim();
    }
    return '';
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
