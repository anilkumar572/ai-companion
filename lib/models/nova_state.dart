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
          wakeWordListening ? 'Ready' : 'Standby',
        NovaAgentState.listening => 'Listening',
        NovaAgentState.thinking => 'Thinking',
        NovaAgentState.speaking => 'Speaking',
        NovaAgentState.error => 'Needs attention',
      };
}
