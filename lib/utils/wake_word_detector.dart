class WakeWordDetector {
  static final RegExp _wakeWord = RegExp(r'\bn[o0]va\b', caseSensitive: false);

  static bool containsWakeWord(String text) {
    return _wakeWord.hasMatch(text.trim());
  }

  static String extractCommand(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceFirst(
      RegExp(r'^\s*(hey|hi|hello)\s+', caseSensitive: false),
      '',
    );

    final match = _wakeWord.firstMatch(cleaned);
    if (match == null) return '';

    return cleaned.substring(match.end).trim();
  }

  static bool shouldProcess(String transcript, bool isFinal) {
    if (!containsWakeWord(transcript)) return false;

    final command = extractCommand(transcript);
    if (command.isEmpty) return isFinal;
    return isFinal || command.split(RegExp(r'\s+')).length >= 2;
  }
}
