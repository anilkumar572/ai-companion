import 'package:flutter_test/flutter_test.dart';
import 'package:nova/utils/wake_word_detector.dart';

void main() {
  test('detects nova wake word', () {
    expect(WakeWordDetector.containsWakeWord('hey nova'), isTrue);
    expect(WakeWordDetector.containsWakeWord('hello world'), isFalse);
  });

  test('extracts command after wake word', () {
    expect(
      WakeWordDetector.extractCommand('Nova what time is it'),
      'what time is it',
    );
    expect(
      WakeWordDetector.extractCommand('hey nova call john'),
      'call john',
    );
  });

  test('processes combined wake word and command', () {
    expect(
      WakeWordDetector.shouldProcess('nova search for flutter', true),
      isTrue,
    );
    expect(
      WakeWordDetector.shouldProcess('nova', true),
      isTrue,
    );
  });
}
