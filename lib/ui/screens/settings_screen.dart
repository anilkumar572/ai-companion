import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/operation_mode.dart';
import '../../models/voice_gender.dart';
import '../../providers/nova_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _languageController;
  late final TextEditingController _localModelPathController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _languageController = TextEditingController();
    _localModelPathController = TextEditingController();
  }

  @override
  void dispose() {
    _languageController.dispose();
    _localModelPathController.dispose();
    super.dispose();
  }

  void _syncControllers(NovaProvider provider) {
    if (_initialized) return;
    _languageController.text = provider.preferredLanguage;
    _localModelPathController.text = provider.localModelPath;
    _initialized = true;
  }

  Future<void> _saveLanguage(NovaProvider provider) async {
    await provider.setPreferredLanguage(_languageController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Language preference saved')),
    );
  }

  Future<void> _saveOfflineSettings(NovaProvider provider) async {
    await provider.updateLocalModelPath(_localModelPathController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offline settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NovaProvider>();
    _syncControllers(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('> CONFIG_PANEL'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Operation Mode',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: NovaTheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.isOnlineActive
                ? 'Online: Sarvam stream STT, worker chat (Gemini), Cartesia TTS — all keys stay on Cloudflare.'
                : 'Offline: on-device STT, local brain, device TTS.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NovaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          ...OperationMode.values.map(
            (mode) => _ModeOptionTile(
              mode: mode,
              selected: provider.operationMode == mode,
              onTap: () => provider.setOperationMode(mode),
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            title: 'Cloud backend',
            body:
                'Worker: ${NovaConstants.workerUrl}\n'
                'STT: wss://.../stt/ws (Sarvam stream)\n'
                'Chat: POST /chat (Gemini)\n'
                'TTS: POST /tts (Cartesia)\n\n'
                'Set GOOGLE_AI_API_KEY, SARVAM_API_KEY, and CARTESIA_API_KEY as Cloudflare Worker secrets. The app stores no API keys.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NovaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: NovaTheme.textMuted.withValues(alpha: 0.15),
              ),
            ),
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
                  'Used for worker chat and Cartesia TTS when online.',
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NovaTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: NovaTheme.textMuted.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Local LLM',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: NovaTheme.accent,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optional GGUF model path for future on-device inference. Without a model, Nova uses the built-in offline companion engine.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NovaTheme.textMuted,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Local model path (.gguf)',
                  controller: _localModelPathController,
                  hint: '/storage/emulated/0/Download/model.gguf',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _saveOfflineSettings(provider),
                    child: const Text('Save Offline Settings'),
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
            'Male or female. Online Cartesia voice IDs are configured on the worker.',
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
            title: 'Change Cartesia voice (worker)',
            body:
                'Set CARTESIA_VOICE_ID and CARTESIA_MALE_VOICE_ID in Cloudflare Worker secrets/vars. The app only sends gender (male/female).',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Change Sarvam language (worker)',
            body:
                'Set SARVAM_LANGUAGE_CODE on the worker (e.g. unknown, hi-IN, te-IN). The app connects to /stt/ws and the worker proxies Sarvam streaming STT.',
          ),
        ],
      ),
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  const _ModeOptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final OperationMode mode;
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
                mode == OperationMode.offline
                    ? Icons.offline_bolt
                    : mode == OperationMode.online
                        ? Icons.cloud
                        : Icons.sync,
                color: selected ? NovaTheme.primary : NovaTheme.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  mode.label,
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
