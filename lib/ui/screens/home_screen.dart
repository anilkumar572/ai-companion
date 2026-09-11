import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/nova_state.dart';
import '../../providers/nova_provider.dart';
import '../widgets/grid_background.dart';
import '../widgets/nova_orb.dart';
import '../widgets/status_hud.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NovaProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovaProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          NovaConstants.appName.toUpperCase(),
          style: const TextStyle(letterSpacing: 6),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const GridBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    NovaConstants.tagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NovaTheme.textMuted,
                          letterSpacing: 2,
                        ),
                  ).animate().fadeIn(duration: 500.ms),
                  const Spacer(),
                  NovaOrb(
                    state: provider.state,
                    audioLevel: provider.audioLevel,
                    onTap: _handleOrbTap,
                  ).animate().scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1, 1),
                        duration: 700.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 28),
                  StatusHud(
                    state: provider.state,
                    statusMessage: provider.statusMessage,
                    liveTranscript: provider.liveTranscript,
                    lastResponse: provider.lastResponse,
                  ),
                  const Spacer(),
                  _BottomHint(state: provider.state),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOrbTap() {
    final provider = context.read<NovaProvider>();
    switch (provider.state) {
      case NovaAgentState.idle:
      case NovaAgentState.error:
        provider.startListening();
      case NovaAgentState.listening:
        provider.stopListening();
      case NovaAgentState.speaking:
        provider.stopSpeaking();
      case NovaAgentState.thinking:
        break;
    }
  }
}

class _BottomHint extends StatelessWidget {
  const _BottomHint({required this.state});

  final NovaAgentState state;

  @override
  Widget build(BuildContext context) {
    final hint = switch (state) {
      NovaAgentState.idle => 'Tap the orb to activate voice input',
      NovaAgentState.listening => 'Speak now. Tap again when finished',
      NovaAgentState.thinking => 'Nova is analyzing your request',
      NovaAgentState.speaking => 'Tap to interrupt response',
      NovaAgentState.error => 'Check permissions and try again',
    };

    return Text(
      hint,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: NovaTheme.textMuted,
            letterSpacing: 1.2,
          ),
    );
  }
}
