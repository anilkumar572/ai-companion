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

  test('Nova greets formally', () async {
    final prefs = await SharedPreferences.getInstance();
    final agent = NovaAgent(
      reminders: ReminderService(prefs),
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );

    final response = await agent.respond('Hello Nova');
    expect(response.toLowerCase(), contains('nova'));
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
    expect(response.toLowerCase(), contains('reminder recorded'));
    expect(reminders.upcoming(), isNotEmpty);
  });
}
