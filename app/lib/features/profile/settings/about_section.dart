import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// About section — app version, build flavor, licences.
///
/// Version string is read from `package_info_plus` at first build so it
/// tracks `pubspec.yaml` without a source-code edit per release. The
/// pinned `_versionFallback` shows during the very first frame while
/// the platform channel resolves — in practice the channel replies
/// within a frame or two so the fallback is rarely visible.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, Future<PackageInfo>? packageInfo})
      : _packageInfoOverride = packageInfo;

  final Future<PackageInfo>? _packageInfoOverride;

  static const String _versionFallback = '0.1.0-dev';

  @override
  Widget build(BuildContext context) {
    final future = _packageInfoOverride ?? PackageInfo.fromPlatform();
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: FutureBuilder<PackageInfo>(
        future: future,
        builder: (context, snapshot) {
          final info = snapshot.data;
          final version = info == null
              ? _versionFallback
              : (info.buildNumber.isEmpty
                  ? info.version
                  : '${info.version}+${info.buildNumber}');
          return ListView(
            children: [
              const ListTile(
                key: Key('settings.about.appName'),
                leading: Icon(Icons.school_outlined),
                title: Text('Lifestream Learn'),
                subtitle: Text('Learner-first video courses'),
              ),
              ListTile(
                key: const Key('settings.about.version'),
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Version'),
                subtitle: Text(version),
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
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Lifestream Learn',
                  applicationVersion: version,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
