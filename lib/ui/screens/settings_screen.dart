import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/nova_theme.dart';
import '../../models/tts_engine.dart';
import '../../models/voice_gender.dart';
import '../../providers/nova_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _workerUrlController;
  late final TextEditingController _languageController;
  late final TextEditingController _femaleVoiceController;
  late final TextEditingController _maleVoiceController;
  double _speed = 1.0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _workerUrlController = TextEditingController();
    _languageController = TextEditingController();
    _femaleVoiceController = TextEditingController();
    _maleVoiceController = TextEditingController();
  }

  @override
  void dispose() {
    _workerUrlController.dispose();
    _languageController.dispose();
    _femaleVoiceController.dispose();
    _maleVoiceController.dispose();
    super.dispose();
  }

  void _syncControllers(NovaProvider provider) {
    if (_initialized) return;
    _workerUrlController.text = provider.cartesiaWorkerUrl;
    _languageController.text = provider.cartesiaLanguage;
    _femaleVoiceController.text = provider.cartesiaFemaleVoiceId;
    _maleVoiceController.text = provider.cartesiaMaleVoiceId;
    _speed = provider.cartesiaSpeed;
    _initialized = true;
  }

  Future<void> _saveCartesiaSettings(NovaProvider provider) async {
    await provider.updateCartesiaSettings(
      workerUrl: _workerUrlController.text,
      language: _languageController.text,
      speed: _speed,
      femaleVoiceId: _femaleVoiceController.text,
      maleVoiceId: _maleVoiceController.text,
      preview: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cartesia settings saved')),
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
            'Text-to-Speech Engine',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: NovaTheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use device voices or Cartesia neural speech through your Cloudflare worker.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NovaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          ...TtsEngine.values.map(
            (engine) => _EngineOptionTile(
              engine: engine,
              selected: provider.ttsEngine == engine,
              onTap: () => provider.setTtsEngine(engine),
            ),
          ),
          if (provider.ttsEngine == TtsEngine.cartesia) ...[
            const SizedBox(height: 24),
            _CartesiaSettingsCard(
              workerUrlController: _workerUrlController,
              languageController: _languageController,
              femaleVoiceController: _femaleVoiceController,
              maleVoiceController: _maleVoiceController,
              speed: _speed,
              installationId: provider.installationId,
              onSpeedChanged: (value) => setState(() => _speed = value),
              onSave: () => _saveCartesiaSettings(provider),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'Voice Profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: NovaTheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.ttsEngine == TtsEngine.cartesia
                ? 'Male and female map to Cartesia voice IDs below. Nova previews the selected profile immediately.'
                : 'Select whether Nova speaks with a male or female device voice.',
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
            title: 'Cartesia: Change Voice',
            body:
                'Copy a voice ID from the Cartesia dashboard (https://play.cartesia.ai/voices) and paste it into Female Voice ID or Male Voice ID above. Each gender uses its own voice ID.',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Cartesia: Change Language',
            body:
                'Set Language to a locale code such as en-IN, hi-IN, te-IN, ta-IN, kn-IN, or mr-IN. The worker forwards this to Cartesia as locale/language for pronunciation.',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Cartesia Model',
            body:
                'The TTS model (for example sonic-3.6) is configured on the worker as CARTESIA_MODEL. The app sends text, voiceId, language, and speed to ${NovaConstants.defaultCartesiaWorkerUrl}/tts.',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'On-Device Capabilities',
            body:
                'Nova can place calls, search contacts, take photos, record video, manage reminders, review your calendar, and search the web — all from voice commands.',
          ),
        ],
      ),
    );
  }
}

class _EngineOptionTile extends StatelessWidget {
  const _EngineOptionTile({
    required this.engine,
    required this.selected,
    required this.onTap,
  });

  final TtsEngine engine;
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
                engine == TtsEngine.cartesia ? Icons.cloud : Icons.phone_android,
                color: selected ? NovaTheme.primary : NovaTheme.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  engine.label,
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

class _CartesiaSettingsCard extends StatelessWidget {
  const _CartesiaSettingsCard({
    required this.workerUrlController,
    required this.languageController,
    required this.femaleVoiceController,
    required this.maleVoiceController,
    required this.speed,
    required this.installationId,
    required this.onSpeedChanged,
    required this.onSave,
  });

  final TextEditingController workerUrlController;
  final TextEditingController languageController;
  final TextEditingController femaleVoiceController;
  final TextEditingController maleVoiceController;
  final double speed;
  final String installationId;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onSave;

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
            'Cartesia Settings',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: NovaTheme.accent,
                ),
          ),
          const SizedBox(height: 16),
          _SettingsField(
            label: 'Worker URL',
            controller: workerUrlController,
            hint: NovaConstants.defaultCartesiaWorkerUrl,
          ),
          const SizedBox(height: 12),
          _SettingsField(
            label: 'Language',
            controller: languageController,
            hint: 'en-IN',
          ),
          const SizedBox(height: 12),
          _SettingsField(
            label: 'Female Voice ID',
            controller: femaleVoiceController,
            hint: NovaConstants.defaultCartesiaFemaleVoiceId,
          ),
          const SizedBox(height: 12),
          _SettingsField(
            label: 'Male Voice ID',
            controller: maleVoiceController,
            hint: 'Paste a male voice ID from Cartesia',
          ),
          const SizedBox(height: 16),
          Text(
            'Speed: ${speed.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Slider(
            value: speed,
            min: 0.6,
            max: 1.5,
            divisions: 18,
            activeColor: NovaTheme.primary,
            onChanged: onSpeedChanged,
          ),
          const SizedBox(height: 8),
          Text(
            'Installation ID: $installationId',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NovaTheme.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSave,
              child: const Text('Save & Preview Cartesia'),
            ),
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
