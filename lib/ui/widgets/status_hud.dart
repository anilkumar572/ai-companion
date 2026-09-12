import 'dart:io';

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
        _TerminalLine(
          prefix: 'SYS',
          value: state.label(wakeWordListening: wakeWordListening),
          accent: NovaTheme.accent,
        ),
        const SizedBox(height: 8),
        _TerminalLine(
          prefix: 'LOG',
          value: statusMessage,
          accent: NovaTheme.primary,
        ),
        if (liveTranscript.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: 'INPUT_STREAM',
            content: '> $liveTranscript',
            accent: NovaTheme.accent,
          ),
        ],
        if (lastResponse.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Panel(
            title: 'NOVA_OUTPUT',
            content: '> $lastResponse',
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
}

class _TerminalLine extends StatelessWidget {
  const _TerminalLine({
    required this.prefix,
    required this.value,
    required this.accent,
  });

  final String prefix;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NovaTheme.textMuted,
              letterSpacing: 1.2,
            ),
        children: [
          TextSpan(
            text: '[$prefix] ',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: NovaTheme.textPrimary),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 2400.ms,
          color: NovaTheme.primary.withValues(alpha: 0.25),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NovaTheme.panel.withValues(alpha: 0.92),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '// $title',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NovaTheme.secondary,
                  height: 1.55,
                ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms);
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaTheme.panel,
        border: Border.all(color: NovaTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVideo ? '// VIDEO_CAPTURE' : '// IMAGE_CAPTURE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: NovaTheme.accent,
                ),
          ),
          const SizedBox(height: 8),
          if (isVideo)
            Text('> $path', style: Theme.of(context).textTheme.bodySmall)
          else
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                -1, 0, 0, 0, 255,
                0, -1, 0, 0, 255,
                0, 0, -1, 0, 255,
                0, 0, 0, 1, 0,
              ]),
              child: Image.file(
                File(path),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
        ],
      ),
    );
  }
}
