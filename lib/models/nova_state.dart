enum NovaAgentState {
  idle,
  listening,
  thinking,
  speaking,
  error,
}

extension NovaAgentStateLabel on NovaAgentState {
  String get label => switch (this) {
        NovaAgentState.idle => 'Standby',
        NovaAgentState.listening => 'Listening',
        NovaAgentState.thinking => 'Processing',
        NovaAgentState.speaking => 'Responding',
        NovaAgentState.error => 'Attention Required',
      };
}
