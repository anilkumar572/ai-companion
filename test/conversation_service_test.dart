import 'package:flutter_test/flutter_test.dart';
import 'package:nova/services/calendar_service.dart';
import 'package:nova/services/conversation_service.dart';
import 'package:nova/services/nova_agent.dart';
import 'package:nova/services/reminder_service.dart';
import 'package:nova/services/web_search_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ConversationService> buildService() async {
    final prefs = await SharedPreferences.getInstance();
    return ConversationService(
      deviceAgent: NovaAgent(
        reminders: ReminderService(prefs),
        calendar: CalendarService(),
        webSearch: WebSearchService(),
      ),
    );
  }

  test('offline mode uses local engine for open chat', () async {
    final service = await buildService();
    final result = await service.respond(
      input: 'I feel tired today',
      online: false,
      workerBaseUrl: 'https://example.com',
      installationId: 'test-installation',
    );

    expect(result.deferToCloud, isFalse);
    expect(result.message.toLowerCase(), isNot(contains('configured for voice')));
  });

  test('device commands stay local even when online flag is true', () async {
    final service = await buildService();
    final result = await service.respond(
      input: 'Hello Nova',
      online: true,
      workerBaseUrl: 'https://example.com',
      installationId: 'test-installation',
    );

    expect(result.deferToCloud, isFalse);
    expect(result.message.toLowerCase(), contains('nova'));
  });
}
