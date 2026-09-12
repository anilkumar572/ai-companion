import 'offline_companion_engine.dart';

/// Local inference layer for offline mode.
///
/// Today this uses the offline companion engine. A GGUF model path can be added
/// later for true on-device LLM inference.
class LocalLlmService {
  LocalLlmService({
    OfflineCompanionEngine? offlineEngine,
  }) : _offlineEngine = offlineEngine ?? const OfflineCompanionEngine();

  final OfflineCompanionEngine _offlineEngine;
  final List<ChatTurn> _history = [];

  String? modelPath;

  void setModelPath(String? path) {
    modelPath = path?.trim().isEmpty == true ? null : path?.trim();
  }

  Future<String> generate(String message) async {
    final reply = _offlineEngine.reply(message, history: _history);
    _history.add(ChatTurn(role: 'user', content: message));
    _history.add(ChatTurn(role: 'assistant', content: reply));
    if (_history.length > 16) {
      _history.removeRange(0, _history.length - 16);
    }
    return reply;
  }

  void clearHistory() => _history.clear();
}
