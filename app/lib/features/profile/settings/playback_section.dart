import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/settings/settings_cubit.dart';
import '../../../core/settings/settings_state.dart';
import '../../../core/settings/settings_store.dart';
import '../../../core/utils/bcp47_labels.dart';

/// Playback section — default playback speed, captions default,
/// caption language preference, and data saver.
class PlaybackSection extends StatelessWidget {
  const PlaybackSection({super.key});

  void _showLanguagePicker(
    BuildContext context,
    SettingsState state,
    SettingsCubit cubit,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet handle.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Caption language',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const Divider(height: 0),
              // "Use video default" row.
              ListTile(
                key: const Key('settings.captionLanguage.default'),
                title: const Text('Use video default'),
                trailing: state.captionLanguage == null
                    ? const Icon(
                        Icons.check_rounded,
                        key: Key('settings.captionLanguage.default.check'),
                      )
                    : null,
                onTap: () {
                  cubit.setCaptionLanguage(null);
                  Navigator.of(ctx).pop();
                },
              ),
              // Supported languages.
              for (final code in kSupportedCaptionLanguages)
                ListTile(
                  key: Key('settings.captionLanguage.$code'),
                  title: Text(captionLanguageLabel(code)),
                  trailing: state.captionLanguage == code
                      ? Icon(Icons.check,
                          key: Key('settings.captionLanguage.$code.check'))
                      : null,
                  onTap: () {
                    cubit.setCaptionLanguage(code);
                    Navigator.of(ctx).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Playback')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.speed_rounded),
            title: const Text('Default playback speed'),
            subtitle: Text('${state.playbackSpeed.toStringAsFixed(2)}x'),
            trailing: DropdownButton<double>(
              key: const Key('settings.playback.speed'),
              value: state.playbackSpeed,
              items: SettingsStore.allowedPlaybackSpeeds
                  .map(
                    (s) => DropdownMenuItem<double>(
                      value: s,
                      child: Text('${s.toStringAsFixed(2)}x'),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next == null) return;
                cubit.setPlaybackSpeed(next);
              },
            ),
          ),
          const Divider(height: 0),
          SwitchListTile(
            key: const Key('settings.playback.captions'),
            secondary: const Icon(Icons.closed_caption_outlined),
            title: const Text('Show captions by default'),
            subtitle: const Text(
              'When on, captions load automatically at the start of each '
              'video.',
            ),
            value: state.captionsDefault,
            onChanged: cubit.setCaptionsDefault,
          ),
          const Divider(height: 0),
          ListTile(
            key: const Key('settings.playback.captionLanguage'),
            enabled: state.captionsDefault,
            leading: Icon(
              Icons.language_rounded,
              color: state.captionsDefault ? null : Theme.of(context).disabledColor,
            ),
            title: Text(
              'Caption language',
              style: TextStyle(
                color: state.captionsDefault
                    ? null
                    : Theme.of(context).disabledColor,
              ),
            ),
            subtitle: Text(
              state.captionLanguage != null
                  ? captionLanguageLabel(state.captionLanguage!)
                  : 'Use video default',
              style: TextStyle(
                color: state.captionsDefault
                    ? null
                    : Theme.of(context).disabledColor,
              ),
            ),
            onTap: state.captionsDefault
                ? () => _showLanguagePicker(context, state, cubit)
                : null,
          ),
          const Divider(height: 0),
          SwitchListTile(
            key: const Key('settings.playback.dataSaver'),
            secondary: const Icon(Icons.data_saver_off_outlined),
            title: const Text('Data saver'),
            subtitle: const Text(
              'On cellular, videos wait for you to tap play instead of '
              'auto-playing — saves data when you\'re off Wi-Fi.',
            ),
            value: state.dataSaver,
            onChanged: cubit.setDataSaver,
          ),
        ],
      ),
    );
  }
}
