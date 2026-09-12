import 'package:flutter_test/flutter_test.dart';
import 'package:nova/services/calendar_service.dart';
import 'package:nova/services/nova_agent.dart';
import 'package:nova/services/reminder_service.dart';
import 'package:nova/services/web_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  NovaAgent buildAgent(SharedPreferences prefs) {
    return NovaAgent(
      reminders: ReminderService(prefs),
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );
  }

  test('Nova greets formally', () async {
    final prefs = await SharedPreferences.getInstance();
    final response = await buildAgent(prefs).respond('Hello Nova');
    expect(response.message.toLowerCase(), contains('nova'));
  });

  test('Nova creates reminders from voice commands', () async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = ReminderService(prefs);
    final agent = NovaAgent(
      reminders: reminders,
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );

    final response = await agent.respond('Remind me to call the client at 5 PM');
    expect(response.message.toLowerCase(), contains('reminder recorded'));
    expect(reminders.upcoming(), isNotEmpty);
  });

  test('Nova routes questions to web search instead of fallback text', () async {
    final prefs = await SharedPreferences.getInstance();
    final response = await buildAgent(prefs).respond('What is artificial intelligence');
    expect(
      response.message.toLowerCase(),
      isNot(contains('configured for voice assistance')),
    );
  });

  test('Nova handles voice change commands', () async {
    final prefs = await SharedPreferences.getInstance();
    final response = await buildAgent(prefs).respond('Change voice to male');
    expect(response.voiceGenderChange, isNotNull);
    expect(response.message.toLowerCase(), contains('male voice'));
  });
}
