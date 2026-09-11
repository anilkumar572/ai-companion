import 'package:flutter_test/flutter_test.dart';
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
    expect(response, contains('Nova'));
    expect(response, contains('formal'));
  });
}
