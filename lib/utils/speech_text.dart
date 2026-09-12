/// Normalizes text for natural text-to-speech playback.
String normalizeForSpeech(String text) {
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
  out = out.replaceAll(RegExp(r'\n+'), ', ');
  out = out.replaceAllMapped(
    RegExp(r'\s*([,.!?;:])\s*'),
    (match) => '${match.group(1)!} ',
  );
  out = out.replaceAll(RegExp(r',{2,}'), ',');
  out = out.replaceAll(RegExp(r'\.{2,}'), '.');
  out = out.replaceAll(RegExp(r'\.\s*\.'), '.');
  out = out.replaceAll(RegExp(r',\s*\.'), '.');
  out = out.replaceAll(RegExp(r';\s*'), ', ');
  out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
  out = out.trim();

  if (out.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(out)) {
    out = '$out.';
  }
  return out;
}
