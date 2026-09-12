import 'package:flutter_test/flutter_test.dart';
import 'package:nova/utils/speech_text.dart';

void main() {
  test('turns markdown lists into spoken sentences', () {
    expect(
      normalizeForSpeech('**Hello**\n- first item\n- second item'),
      'Hello. First item. Second item.',
    );
  });

  test('adds closing punctuation when missing', () {
    expect(normalizeForSpeech('Good morning'), 'Good morning.');
  });

  test('removes duplicate punctuation', () {
    expect(normalizeForSpeech('Hello..  world'), 'Hello. World.');
  });

  test('splits comma-heavy run-ons into sentences', () {
    expect(
      normalizeForSpeech('Yes, I can help, and I am ready now'),
      'Yes, I can help. I am ready now.',
    );
  });

  test('limits very long replies to a few sentences', () {
    final result = normalizeForSpeech(
      'One. Two. Three. Four. Five. Six.',
      maxSentences: 3,
    );
    expect(result, 'One. Two. Three.');
  });
}
