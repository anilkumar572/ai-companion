enum NovaAgentState {
  idle,
  listening,
  thinking,
  speaking,
  error,
}

extension NovaAgentStateLabel on NovaAgentState {
  String get label => switch (this) {
        NovaAgentState.idle => 'Ready',
        NovaAgentState.listening => 'Listening',
        NovaAgentState.thinking => 'Thinking',
        NovaAgentState.speaking => 'Speaking',
        NovaAgentState.error => 'Needs attention',
      };
}
