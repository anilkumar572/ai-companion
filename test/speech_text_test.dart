import 'package:flutter_test/flutter_test.dart';
import 'package:nova/utils/speech_text.dart';

void main() {
  test('normalizes markdown and newlines for speech', () {
    expect(
      normalizeForSpeech('**Hello**\n- first item\n- second item'),
      'Hello, first item, second item.',
    );
  });

  test('adds closing punctuation when missing', () {
    expect(normalizeForSpeech('Good morning'), 'Good morning.');
  });

  test('removes duplicate punctuation', () {
    expect(normalizeForSpeech('Hello..  world'), 'Hello. world.');
  });
}
