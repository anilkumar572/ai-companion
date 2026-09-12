import 'package:flutter_test/flutter_test.dart';
import 'package:nova/utils/wake_word_detector.dart';

void main() {
  test('detects teju wake word', () {
    expect(WakeWordDetector.containsWakeWord('hey teju'), isTrue);
    expect(WakeWordDetector.containsWakeWord('hello world'), isFalse);
  });

  test('extracts command after wake word', () {
    expect(
      WakeWordDetector.extractCommand('Teju what time is it'),
      'what time is it',
    );
    expect(
      WakeWordDetector.extractCommand('hey teju call john'),
      'call john',
    );
  });

  test('processes combined wake word and command', () {
    expect(
      WakeWordDetector.shouldProcess('teju search for flutter', true),
      isTrue,
    );
    expect(
      WakeWordDetector.shouldProcess('teju', true),
      isTrue,
    );
  });
}
