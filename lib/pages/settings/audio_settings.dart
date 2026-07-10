import 'package:daily_you/config_provider.dart';
import 'package:daily_you/widgets/settings_toggle.dart';
import 'package:flutter/material.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class AudioSettings extends StatefulWidget {
  const AudioSettings({super.key});

  @override
  State<AudioSettings> createState() => _AudioSettingsState();
}

class _AudioSettingsState extends State<AudioSettings> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsAudioTitle),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          SettingsToggle(
            title: AppLocalizations.of(context)!.settingsAutoPlayAudio,
            settingsKey: ConfigKey.autoPlayAudio,
            onChanged: (value) {
              configProvider.set(ConfigKey.autoPlayAudio, value);
            },
          ),
        ],
      ),
    );
  }
}
