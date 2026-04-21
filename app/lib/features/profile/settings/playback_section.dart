import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/settings/settings_cubit.dart';
import '../../../core/settings/settings_store.dart';

/// Playback section — default playback speed, captions default, data
/// saver.
///
/// The speed is consumed by [LearnVideoPlayer] when a controller
/// initialises. Captions and data saver are persisted but not yet
/// fully wired — both are flagged as "coming soon" in copy so users
/// aren't surprised.
class PlaybackSection extends StatelessWidget {
  const PlaybackSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Playback')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.speed),
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
              'Captions are coming soon. Your preference is saved for '
              'when they land.',
            ),
            value: state.captionsDefault,
            onChanged: cubit.setCaptionsDefault,
          ),
          const Divider(height: 0),
          SwitchListTile(
            key: const Key('settings.playback.dataSaver'),
            secondary: const Icon(Icons.data_saver_off_outlined),
            title: const Text('Data saver'),
            subtitle: const Text(
              'Limits video quality on cellular — coming soon.',
            ),
            value: state.dataSaver,
            onChanged: cubit.setDataSaver,
          ),
        ],
      ),
    );
  }
}
