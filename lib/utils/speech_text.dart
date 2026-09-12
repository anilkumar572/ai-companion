/// Normalizes text for natural text-to-speech playback.
String normalizeForSpeech(String text, {int maxSentences = 4}) {
  var out = text.trim();
  if (out.isEmpty) return '';

  out = out.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*'),
    (match) => match.group(1)!,
  );
  out = out.replaceAllMapped(
    RegExp(r'\*([^*]+)\*'),
    (match) => match.group(1)!,
  );
  out = out.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (match) => match.group(1)!,
  );
  out = out.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (match) => match.group(1)!,
  );
  out = out.replaceAll(RegExp(r'https?:\/\/\S+', caseSensitive: false), '');
  out = out.replaceAll(RegExp(r'^[-*•]\s+', multiLine: true), '');
  out = out.replaceAll(RegExp(r'^\d+[.)]\s+', multiLine: true), '');
  out = out.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true), '');
  out = out.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '');

  // Sentence breaks, not comma chains — commas sound unnatural in TTS.
  out = out.replaceAll(RegExp(r'\n\s*\n+'), '. ');
  out = out.replaceAll(RegExp(r'\n+'), '. ');
  out = out.replaceAll(RegExp(r';\s*'), '. ');

  final latinHeavy = RegExp(r'[A-Za-z]').hasMatch(out);
  if (latinHeavy) {
    out = out.replaceAll(
      RegExp(
        r',\s+(and|but|so|because|however|also|then|yet)\s+',
        caseSensitive: false,
      ),
      '. ',
    );
  }

  out = out.replaceAllMapped(
    RegExp(r'\s*([,.!?])\s*'),
    (match) => '${match.group(1)!} ',
  );
  out = out.replaceAll(RegExp(r',{2,}'), ',');
  out = out.replaceAll(RegExp(r'\.{2,}'), '.');
  out = out.replaceAll(RegExp(r'\.\s*\.'), '.');
  out = out.replaceAll(RegExp(r',\s*\.'), '.');
  out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
  out = out.trim();

  final sentences = out
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (sentences.length > maxSentences) {
    out = sentences.take(maxSentences).join(' ');
  } else if (sentences.isNotEmpty) {
    out = sentences.join(' ');
  }

  if (latinHeavy) {
    out = out.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-z])'),
      (match) => '${match.group(1)!}${match.group(2)!.toUpperCase()}',
    );
  }

  if (out.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(out)) {
    out = '$out.';
  }

  return out;
}
