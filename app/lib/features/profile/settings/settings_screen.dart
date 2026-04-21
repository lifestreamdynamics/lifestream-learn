import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Settings hub — entry point from the Profile screen. Users drill
/// into section-specific sub-screens from here; the hub itself just
/// lists the categories.
///
/// The SettingsCubit is expected to be provided above this widget in
/// the widget tree (wired at the app root). All sub-screens consume
/// the same cubit via `context.watch<SettingsCubit>()`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _SectionHeader('App'),
          _SettingsTile(
            keyValue: Key('settings.entry.appearance'),
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme (System / Light / Dark)',
            route: '/profile/settings/appearance',
          ),
          _SettingsTile(
            keyValue: Key('settings.entry.playback'),
            icon: Icons.play_circle_outline,
            title: 'Playback',
            subtitle: 'Speed, captions, data saver',
            route: '/profile/settings/playback',
          ),
          _SettingsTile(
            keyValue: Key('settings.entry.accessibility'),
            icon: Icons.accessibility_new_outlined,
            title: 'Accessibility',
            subtitle: 'Text size, reduce motion',
            route: '/profile/settings/accessibility',
          ),
          _SectionHeader('Privacy'),
          _SettingsTile(
            keyValue: Key('settings.entry.privacy'),
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & data',
            subtitle: 'Analytics, crash reports',
            route: '/profile/settings/privacy',
          ),
          _SectionHeader('About'),
          _SettingsTile(
            keyValue: Key('settings.entry.about'),
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version, licences',
            route: '/profile/settings/about',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.keyValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final Key keyValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: keyValue,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => GoRouter.of(context).push(route),
    );
  }
}
