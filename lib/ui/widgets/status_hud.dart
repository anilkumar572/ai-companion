import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/nova_theme.dart';
import '../../models/nova_state.dart';

class StatusHud extends StatelessWidget {
  const StatusHud({
    super.key,
    required this.state,
    required this.statusMessage,
    required this.liveTranscript,
    required this.lastResponse,
  });

  final NovaAgentState state;
  final String statusMessage;
  final String liveTranscript;
  final String lastResponse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          state.label.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: NovaTheme.primary,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
        ).animate(onPlay: (controller) => controller.repeat()).shimmer(
              duration: 2200.ms,
              color: Colors.white.withValues(alpha: 0.35),
            ),
        const SizedBox(height: 12),
        Text(
          statusMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: NovaTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
        if (liveTranscript.isNotEmpty) ...[
          const SizedBox(height: 18),
          _Panel(
            title: 'YOU',
            content: liveTranscript,
            accent: NovaTheme.accent,
          ),
        ],
        if (lastResponse.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Panel(
            title: 'NOVA',
            content: lastResponse,
            accent: NovaTheme.primary,
          ),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.content,
    required this.accent,
  });

  final String title;
  final String content;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NovaTheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  letterSpacing: 2.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NovaTheme.textMuted,
                  height: 1.5,
                ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.08, end: 0);
  }
}
