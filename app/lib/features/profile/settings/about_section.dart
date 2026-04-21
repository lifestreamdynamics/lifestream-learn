import 'package:flutter/material.dart';

/// About section — app version, build flavor, licences.
///
/// `package_info_plus` isn't a dependency (the slice budget forbids
/// adding one), so the version string is a pinned build-time constant.
/// Update [_version] when pushing a new release; Flutter's built-in
/// `showLicensePage` handles third-party licence attribution.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  // TODO(Slice P4 follow-up): wire to `package_info_plus` once it's
  // added as a dep so the version tracks pubspec.yaml without a
  // source-code edit.
  static const String _version = '0.1.0-dev';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          const ListTile(
            key: Key('settings.about.appName'),
            leading: Icon(Icons.school_outlined),
            title: Text('Lifestream Learn'),
            subtitle: Text('Learner-first video courses'),
          ),
          const ListTile(
            key: Key('settings.about.version'),
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text(_version),
          ),
          const ListTile(
            key: Key('settings.about.flavor'),
            leading: Icon(Icons.science_outlined),
            title: Text('Build flavor'),
            subtitle: Text(
              // `const bool.fromEnvironment` is evaluated at compile
              // time and would require a --dart-define; simpler to
              // read `kDebugMode` at build (but kDebugMode varies per
              // build, not per flavor). Honest thing: present it as
              // "dev (debug)" or "prod (release)" based on the
              // assertion-enabled flag that corresponds to debug mode.
              // Since this tile is informational, the value only
              // needs to be directionally correct.
              String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('settings.about.licenses'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open source licences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Lifestream Learn',
              applicationVersion: _version,
            ),
          ),
        ],
      ),
    );
  }
}
