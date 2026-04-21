import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/settings/settings_cubit.dart';
import '../../../core/settings/settings_state.dart';

/// Appearance section — theme mode (System / Light / Dark).
///
/// The underlying `MaterialApp.themeMode` is wired in `main.dart` to
/// `context.watch<SettingsCubit>().state.themeMode`, so a change here
/// recolours the whole app on the next frame.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Theme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            key: const Key('settings.appearance.themeMode'),
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: <ThemeMode>{state.themeMode},
            onSelectionChanged: (selection) {
              // SegmentedButton in single-select mode passes exactly
              // one entry.
              context.read<SettingsCubit>().setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 24),
          Text(
            _describe(state),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _describe(SettingsState state) {
    switch (state.themeMode) {
      case ThemeMode.system:
        return 'Follows your device setting. Switches automatically.';
      case ThemeMode.light:
        return 'Always use the light theme.';
      case ThemeMode.dark:
        return 'Always use the dark theme.';
    }
  }
}
