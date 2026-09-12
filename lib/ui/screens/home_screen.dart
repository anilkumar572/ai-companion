import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/nova_state.dart';
import '../../providers/nova_provider.dart';
import '../widgets/nova_background.dart';
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: NovaTheme.accentGradient,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              NovaConstants.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
            ),
          ],
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
          const NovaBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  _ModeChip(isOnline: provider.isOnlineActive),
                  const SizedBox(height: 10),
                  Text(
                    NovaConstants.tagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NovaTheme.textMuted,
                          letterSpacing: 0.2,
                          height: 1.4,
                        ),
                  ).animate().fadeIn(duration: 500.ms),
                  const Spacer(),
                  NovaOrb(
                    state: provider.state,
                    audioLevel: provider.audioLevel,
                    wakeWordListening: provider.wakeWordListening,
                    onTap: _handleOrbTap,
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 16),
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NovaTheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isOnline ? NovaTheme.accent : NovaTheme.textMuted)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.cloud_outlined : Icons.offline_bolt_outlined,
            size: 14,
            color: isOnline ? NovaTheme.accent : NovaTheme.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isOnline ? NovaTheme.accent : NovaTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
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
        'Say "Nova" or tap the orb to speak',
      NovaAgentState.idle => 'Tap the orb to start a conversation',
      NovaAgentState.listening => 'Listening… tap the orb when you are done',
      NovaAgentState.thinking => 'Thinking through your request',
      NovaAgentState.speaking => 'Tap the orb to interrupt',
      NovaAgentState.error => 'Check microphone permissions and try again',
    };

    return Text(
      hint,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: NovaTheme.textMuted,
            height: 1.45,
          ),
    );
  }
}
