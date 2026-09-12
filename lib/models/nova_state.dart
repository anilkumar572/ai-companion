enum NovaAgentState {
  idle,
  listening,
  thinking,
  speaking,
  error,
}

extension NovaAgentStateLabel on NovaAgentState {
  String label({bool wakeWordListening = false}) => switch (this) {
        NovaAgentState.idle =>
          wakeWordListening ? 'SCANNING' : 'STANDBY',
        NovaAgentState.listening => 'LISTENING',
        NovaAgentState.thinking => 'PROCESSING',
        NovaAgentState.speaking => 'RESPONDING',
        NovaAgentState.error => 'FAULT',
      };
}
