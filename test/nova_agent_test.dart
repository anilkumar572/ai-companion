import 'package:flutter_test/flutter_test.dart';
import 'package:nova/models/voice_gender.dart';
import 'package:nova/services/calendar_service.dart';
import 'package:nova/services/nova_agent.dart';
import 'package:nova/services/reminder_service.dart';
import 'package:nova/services/web_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Nova identifies itself formally', () async {
    final prefs = await SharedPreferences.getInstance();
    final agent = NovaAgent(
      reminders: ReminderService(prefs),
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );

    final response = await agent.respond('Who are you?');
    expect(response.message, contains('Nova'));
  });

  test('Hey Nova with a question defers to cloud', () async {
    final prefs = await SharedPreferences.getInstance();
    final agent = NovaAgent(
      reminders: ReminderService(prefs),
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );

    final response = await agent.respond(
      'Hey Nova, how are you?',
      allowCloudDeferral: true,
    );

    expect(response.deferToCloud, isTrue);
  });

  test('Pure greeting stays on device', () async {
    final prefs = await SharedPreferences.getInstance();
    final agent = NovaAgent(
      reminders: ReminderService(prefs),
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );

    final response = await agent.respond('Hey Nova');
    expect(response.deferToCloud, isFalse);
    expect(response.message, contains('Nova is online'));
  });

  test('Nova changes to female voice on command', () async {
    final prefs = await SharedPreferences.getInstance();
    final agent = NovaAgent(
      reminders: ReminderService(prefs),
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );

    final response = await agent.respond('Switch to female voice');
    expect(response.voiceGenderChange, VoiceGender.female);
  });
}
