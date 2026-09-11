import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/voice_gender.dart';
import '../../providers/nova_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Voice Profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: NovaTheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select whether Nova speaks with a male or female voice.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NovaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 20),
          ...VoiceGender.values.map(
            (gender) => _VoiceOptionTile(
              gender: gender,
              selected: provider.voiceGender == gender,
              onTap: () => provider.setVoiceGender(gender),
            ),
          ),
          const SizedBox(height: 28),
          _InfoCard(
            title: 'Capabilities',
            body:
                'Nova supports voice-only interaction with reminders, calendar summaries, and web search. Interaction is formal and concise by design.',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Agent',
            body:
                '${NovaConstants.appName} is optimized for Android and iOS. Tap the orb to speak, and Nova will listen until you finish your request.',
          ),
        ],
      ),
    );
  }
}

class _VoiceOptionTile extends StatelessWidget {
  const _VoiceOptionTile({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final VoiceGender gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? NovaTheme.primary.withValues(alpha: 0.12)
                : NovaTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? NovaTheme.primary
                  : NovaTheme.textMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                gender == VoiceGender.male ? Icons.male : Icons.female,
                color: selected ? NovaTheme.primary : NovaTheme.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${gender.label} voice',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: NovaTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovaTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NovaTheme.textMuted.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: NovaTheme.accent,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NovaTheme.textMuted,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
