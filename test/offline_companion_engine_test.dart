import 'package:flutter_test/flutter_test.dart';
import 'package:nova/services/offline_companion_engine.dart';

void main() {
  const engine = OfflineCompanionEngine();

  test('offline engine greets formally', () {
    final reply = engine.reply('Hello Nova');
    expect(reply.toLowerCase(), contains('nova'));
  });

  test('offline engine remembers introduced name', () {
    final reply = engine.reply('My name is Anil');
    expect(reply, contains('Anil'));
  });

  test('offline engine handles curious questions', () {
    final reply = engine.reply('What is quantum computing?');
    expect(reply.toLowerCase(), contains('offline mode'));
  });
}
