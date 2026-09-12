import '../core/constants.dart';
import '../models/agent_result.dart';
import 'nova_agent.dart';
import 'worker_chat_service.dart';

class ConversationService {
  ConversationService({
    required NovaAgent deviceAgent,
    WorkerChatService? workerChat,
  })  : _deviceAgent = deviceAgent,
        _workerChat = workerChat ?? const WorkerChatService();

  final NovaAgent _deviceAgent;
  final WorkerChatService _workerChat;
  final List<WorkerChatTurn> _cloudHistory = [];

  Future<AgentResult> respond({
    required String input,
    required String workerBaseUrl,
    required String installationId,
    String language = NovaConstants.defaultLanguage,
  }) async {
    final localResult = await _deviceAgent.respond(
      input,
      allowWebSearch: false,
      allowCloudDeferral: true,
    );

    if (!localResult.deferToCloud) {
      return localResult;
    }

    try {
      final response = await _workerChat.chat(
        workerBaseUrl: workerBaseUrl,
        installationId: installationId,
        message: input,
        language: language,
        personality: 'formal',
        robotName: NovaConstants.appName,
        conversationContext: _cloudHistory,
      );

      _cloudHistory.add(WorkerChatTurn(role: 'user', content: input));
      _cloudHistory.add(WorkerChatTurn(role: 'assistant', content: response.reply));
      if (_cloudHistory.length > 16) {
        _cloudHistory.removeRange(0, _cloudHistory.length - 16);
      }

      return AgentResult(message: response.reply);
    } catch (_) {
      return const AgentResult(
        message:
            'I could not reach the cloud service. Please check your internet connection and try again.',
      );
    }
  }
}
