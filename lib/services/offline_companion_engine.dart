class OfflineCompanionEngine {
  const OfflineCompanionEngine();

  static const _positiveWords = [
    'happy',
    'great',
    'good',
    'awesome',
    'love',
    'excited',
    'glad',
    'wonderful',
    'amazing',
    'fantastic',
    'thanks',
    'thank you',
  ];

  static const _negativeWords = [
    'sad',
    'tired',
    'angry',
    'upset',
    'stressed',
    'anxious',
    'worried',
    'lonely',
    'bad',
    'terrible',
    'hate',
    'depressed',
    'frustrated',
  ];

  static const _greetings = ['hi', 'hello', 'hey', 'yo', 'howdy', 'greetings'];
  static const _farewells = [
    'bye',
    'goodbye',
    'see you',
    'good night',
    'goodnight',
    'later',
  ];

  String reply(String message, {List<ChatTurn> history = const []}) {
    final normalized = message.toLowerCase().trim();
    final nameFromMessage = _extractName(message);
    final userName = nameFromMessage ?? _findKnownName(history);
    final addressed = userName != null ? ', $userName' : '';
    final mood = _detectMood(normalized);

    if (nameFromMessage != null) {
      return "It is a pleasure to meet you, $nameFromMessage. I will remember that. How may I assist you today?";
    }

    if (_containsAny(normalized, _greetings) && normalized.length <= 25) {
      return 'Good day$addressed. I am Nova, your local voice companion. How may I help you?';
    }

    if (_containsAny(normalized, _farewells)) {
      return 'Very well$addressed. I will be here when you need me again.';
    }

    if (_containsAny(normalized, ['thank', 'thanks'])) {
      return 'You are welcome$addressed. It is my pleasure to assist.';
    }

    if (mood == 'negative') {
      return 'I understand this may be difficult$addressed. I am here with you. Would you like to share more?';
    }

    if (mood == 'positive') {
      return 'That is excellent to hear$addressed. What would you like to do next?';
    }

    if (mood == 'curious') {
      return 'That is a thoughtful question$addressed. In offline mode I rely on my local engine, so my answers are limited. I can still help with reminders, calls, contacts, and calendar tasks.';
    }

    if (normalized.isEmpty) {
      return 'I am listening$addressed. Please continue when you are ready.';
    }

    return 'Thank you for sharing that$addressed. In offline mode I can manage reminders, calls, contacts, camera actions, and calendar review. What would you like me to handle?';
  }

  String? _extractName(String text) {
    final patterns = [
      RegExp(r"\bmy name is\s+([a-z][a-z'-]*)", caseSensitive: false),
      RegExp(r"\bi am\s+([a-z][a-z'-]*)", caseSensitive: false),
      RegExp(r"\bi'm\s+([a-z][a-z'-]*)", caseSensitive: false),
      RegExp(r"\bcall me\s+([a-z][a-z'-]*)", caseSensitive: false),
    ];

    const stopWords = {
      'not',
      'so',
      'very',
      'really',
      'feeling',
      'just',
      'here',
      'fine',
      'okay',
      'ok',
    };

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final candidate = match?.group(1)?.trim();
      if (candidate != null &&
          candidate.isNotEmpty &&
          !stopWords.contains(candidate.toLowerCase())) {
        return _capitalize(candidate);
      }
    }
    return null;
  }

  String? _findKnownName(List<ChatTurn> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      if (history[i].role == 'user') {
        final name = _extractName(history[i].content);
        if (name != null) return name;
      }
    }
    return null;
  }

  String _detectMood(String normalized) {
    if (_containsAny(normalized, _negativeWords)) return 'negative';
    if (_containsAny(normalized, _positiveWords)) return 'positive';
    if (normalized.startsWith('what ') ||
        normalized.startsWith('who ') ||
        normalized.startsWith('why ') ||
        normalized.startsWith('how ')) {
      return 'curious';
    }
    return 'neutral';
  }

  bool _containsAny(String text, List<String> words) {
    return words.any((word) => RegExp('\\b$word\\b').hasMatch(text));
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

class ChatTurn {
  const ChatTurn({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;
}
