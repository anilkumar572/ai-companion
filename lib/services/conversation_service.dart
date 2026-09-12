import '../models/agent_result.dart';
import 'local_llm_service.dart';
import 'nova_agent.dart';
import 'worker_chat_service.dart';

class ConversationService {
  ConversationService({
    required NovaAgent deviceAgent,
    WorkerChatService? workerChat,
    LocalLlmService? localLlm,
  })  : _deviceAgent = deviceAgent,
        _workerChat = workerChat ?? const WorkerChatService(),
        _localLlm = localLlm ?? LocalLlmService();

  final NovaAgent _deviceAgent;
  final WorkerChatService _workerChat;
  final LocalLlmService _localLlm;
  final List<WorkerChatTurn> _cloudHistory = [];

  void setLocalModelPath(String? path) => _localLlm.setModelPath(path);

  Future<AgentResult> respond({
    required String input,
    required bool online,
    required String workerBaseUrl,
    required String installationId,
    String language = 'auto',
  }) async {
    final localResult = await _deviceAgent.respond(
      input,
      allowWebSearch: !online,
      allowCloudDeferral: online,
    );

    if (!localResult.deferToCloud) {
      return localResult;
    }

    if (online) {
      try {
        final response = await _workerChat.chat(
          workerBaseUrl: workerBaseUrl,
          installationId: installationId,
          message: input,
          language: language,
          personality: 'formal',
          robotName: 'Nova',
          conversationContext: _cloudHistory,
        );

        _cloudHistory.add(WorkerChatTurn(role: 'user', content: input));
        _cloudHistory.add(WorkerChatTurn(role: 'assistant', content: response.reply));
        if (_cloudHistory.length > 16) {
          _cloudHistory.removeRange(0, _cloudHistory.length - 16);
        }

        return AgentResult(message: response.reply);
      } catch (_) {
        final fallback = await _localLlm.generate(input);
        return AgentResult(message: fallback);
      }
    }

    final offlineReply = await _localLlm.generate(input);
    return AgentResult(message: offlineReply);
  }
}
