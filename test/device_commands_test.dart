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

  Future<NovaAgent> buildAgent() async {
    final prefs = await SharedPreferences.getInstance();
    return NovaAgent(
      reminders: ReminderService(prefs),
      calendar: CalendarService(),
      webSearch: WebSearchService(),
    );
  }

  test('Nova describes on-device capabilities', () async {
    final agent = await buildAgent();
    final response = await agent.respond('What can you do?');

    expect(response.message.toLowerCase(), contains('call'));
    expect(response.message.toLowerCase(), contains('camera'));
    expect(response.message.toLowerCase(), contains('contacts'));
  });

  test('Call command asks for a name when missing', () async {
    final agent = await buildAgent();
    final response = await agent.respond('Make a call');

    expect(response.message.toLowerCase(), contains('who'));
  });
}
