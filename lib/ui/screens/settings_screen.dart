import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/voice_gender.dart';
import '../../providers/nova_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _languageController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _languageController = TextEditingController();
  }

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  void _syncControllers(NovaProvider provider) {
    if (_initialized) return;
    _languageController.text = provider.preferredLanguage;
    _initialized = true;
  }

  Future<void> _saveLanguage(NovaProvider provider) async {
    await provider.setPreferredLanguage(_languageController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Language preference saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovaProvider>();
    _syncControllers(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _InfoCard(
            title: 'Cloud backend',
            body:
                'Worker: ${NovaConstants.workerUrl}\n'
                'STT: device speech recognition\n'
                'Chat: POST /chat (Gemini)\n'
                'TTS: POST /tts (Cartesia)\n\n'
                'Nova requires internet. API keys stay on Cloudflare.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: NovaTheme.glassCard(borderColor: NovaTheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preferred Language',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: NovaTheme.accent,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Used for cloud chat and Cartesia voice.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NovaTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Language',
                  controller: _languageController,
                  hint: 'en-IN, hi-IN, te-IN',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _saveLanguage(provider),
                    child: const Text('Save Language'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Voice Profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: NovaTheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cartesia voice IDs are configured on the worker.',
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
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Cartesia voice (worker)',
            body:
                'Set CARTESIA_VOICE_ID and CARTESIA_MALE_VOICE_ID in Cloudflare Worker secrets/vars.',
          ),
        ],
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
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
                ? NovaTheme.primary.withValues(alpha: 0.14)
                : NovaTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? NovaTheme.primary.withValues(alpha: 0.65)
                  : NovaTheme.grid.withValues(alpha: 0.8),
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
      decoration: NovaTheme.glassCard(borderColor: NovaTheme.secondary),
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
