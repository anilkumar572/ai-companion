import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/nova_state.dart';
import '../../providers/nova_provider.dart';
import '../widgets/hacker_background.dart';
import '../widgets/nova_orb.dart';
import '../widgets/scanlines_overlay.dart';
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
          '> ${NovaConstants.appName.toUpperCase()}_SYS',
          style: const TextStyle(
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(color: NovaTheme.primary, blurRadius: 12),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.terminal_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const HackerBackground(),
          const ScanlinesOverlay(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    NovaConstants.tagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: NovaTheme.textMuted,
                          letterSpacing: 1.5,
                        ),
                  ).animate().fadeIn(duration: 500.ms),
                  const Spacer(),
                  NovaOrb(
                    state: provider.state,
                    audioLevel: provider.audioLevel,
                    wakeWordListening: provider.wakeWordListening,
                    onTap: _handleOrbTap,
                  ),
                  const SizedBox(height: 22),
                  StatusHud(
                    state: provider.state,
                    statusMessage: provider.statusMessage,
                    liveTranscript: provider.liveTranscript,
                    lastResponse: provider.lastResponse,
                    mediaPath: provider.lastMediaPath,
                    isVideo: provider.lastMediaIsVideo,
                    wakeWordListening: provider.wakeWordListening,
                  ),
                  const Spacer(),
                  _BottomHint(
                    state: provider.state,
                    wakeWordListening: provider.wakeWordListening,
                  ),
                  const SizedBox(height: 14),
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
  const _BottomHint({
    required this.state,
    required this.wakeWordListening,
  });

  final NovaAgentState state;
  final bool wakeWordListening;

  @override
  Widget build(BuildContext context) {
    final hint = switch (state) {
      NovaAgentState.idle when wakeWordListening =>
        '> say "nova" to activate // tap core for manual uplink',
      NovaAgentState.idle => '> tap core for manual uplink',
      NovaAgentState.listening => '> uplink open — speak your command',
      NovaAgentState.thinking => '> decrypting request...',
      NovaAgentState.speaking => '> tap core to interrupt transmission',
      NovaAgentState.error => '> check mic permissions and reboot link',
    };

    return Text(
      hint,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: NovaTheme.textMuted,
            letterSpacing: 0.8,
            height: 1.4,
          ),
    );
  }
}
