import 'dart:io';
import 'dart:ui';

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
    this.mediaPath,
    this.isVideo = false,
    this.wakeWordListening = false,
  });

  final NovaAgentState state;
  final String statusMessage;
  final String liveTranscript;
  final String lastResponse;
  final String? mediaPath;
  final bool isVideo;
  final bool wakeWordListening;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusChip(
          state: state,
          wakeWordListening: wakeWordListening,
        ),
        const SizedBox(height: 12),
        _GlassLine(
          icon: Icons.auto_awesome_outlined,
          label: 'Status',
          value: _humanizeStatus(statusMessage),
        ),
        if (liveTranscript.isNotEmpty) ...[
          const SizedBox(height: 10),
          _GlassPanel(
            title: 'You said',
            content: liveTranscript,
            accent: NovaTheme.accent,
          ),
        ],
        if (lastResponse.isNotEmpty) ...[
          const SizedBox(height: 10),
          _GlassPanel(
            title: 'Nova',
            content: lastResponse,
            accent: NovaTheme.primary,
          ),
        ],
        if (mediaPath != null && File(mediaPath!).existsSync()) ...[
          const SizedBox(height: 10),
          _MediaPreview(path: mediaPath!, isVideo: isVideo),
        ],
      ],
    );
  }

  String _humanizeStatus(String raw) {
    return raw
        .replaceAll('> ', '')
        .replaceAll('::', ' · ')
        .replaceAll('_', ' ')
        .trim();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.state,
    required this.wakeWordListening,
  });

  final NovaAgentState state;
  final bool wakeWordListening;

  @override
  Widget build(BuildContext context) {
    final color = _colorForState(state);
    final label = state.label(wakeWordListening: wakeWordListening);

    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: NovaTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForState(NovaAgentState state) {
    return switch (state) {
      NovaAgentState.idle => NovaTheme.secondary,
      NovaAgentState.listening => NovaTheme.accent,
      NovaAgentState.thinking => NovaTheme.primary,
      NovaAgentState.speaking => NovaTheme.success,
      NovaAgentState.error => NovaTheme.warning,
    };
  }
}

class _GlassLine extends StatelessWidget {
  const _GlassLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: NovaTheme.glassCard(radius: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: NovaTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: NovaTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: NovaTheme.textPrimary,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.title,
    required this.content,
    required this.accent,
  });

  final String title;
  final String content;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: NovaTheme.glassCard(borderColor: accent, radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NovaTheme.textPrimary.withValues(alpha: 0.92),
                      height: 1.55,
                    ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.04, end: 0);
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.path,
    required this.isVideo,
  });

  final String path;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: NovaTheme.glassCard(borderColor: NovaTheme.secondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVideo ? 'Video capture' : 'Photo capture',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: NovaTheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          if (isVideo)
            Text(
              path,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NovaTheme.textMuted,
                  ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(path),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}
