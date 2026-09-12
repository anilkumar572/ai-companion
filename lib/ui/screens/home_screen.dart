import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../utils/wake_word_detector.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NovaProvider>().bootstrap();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final provider = context.read<NovaProvider>();
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.detached) {
      provider.releaseMicrophone();
      return;
    }

    if (lifecycleState == AppLifecycleState.resumed) {
      provider.resumeWakeWordIfNeeded();
    }
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
                  const SizedBox(height: 16),
                  NovaOrb(
                    state: provider.state,
                    audioLevel: provider.audioLevel,
                    wakeWordListening: provider.wakeWordListening,
                    onTap: _handleOrbTap,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: StatusHud(
                        state: provider.state,
                        statusMessage: provider.statusMessage,
                        liveTranscript: provider.liveTranscript,
                        lastResponse: provider.lastResponse,
                        mediaPath: provider.lastMediaPath,
                        isVideo: provider.lastMediaIsVideo,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BottomHint(
                    state: provider.state,
                    wakeWordEnabled: provider.wakeWordEnabled,
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

class _BottomHint extends StatelessWidget {
  const _BottomHint({
    required this.state,
    required this.wakeWordEnabled,
    required this.wakeWordListening,
  });

  final NovaAgentState state;
  final bool wakeWordEnabled;
  final bool wakeWordListening;

  @override
  Widget build(BuildContext context) {
    final hint = switch (state) {
      NovaAgentState.idle => wakeWordEnabled
          ? wakeWordListening
              ? 'Listening for ${WakeWordDetector.wakeWordHint()} — or tap the orb'
              : 'Say ${WakeWordDetector.wakeWordHint()} to speak — or tap the orb'
          : 'Tap the orb to speak',
      NovaAgentState.listening =>
        'Speak your command now — or tap the orb when finished',
      NovaAgentState.thinking => 'Thinking through your request',
      NovaAgentState.speaking => 'Tap the orb to stop speaking',
      NovaAgentState.error => 'Tap the orb to try again',
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
