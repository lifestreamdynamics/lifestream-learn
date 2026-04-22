import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/settings_cubit.dart';

/// Privacy & data section — analytics opt-out, crash reporting opt-out,
/// Privacy Policy + Terms links.
///
/// - The analytics toggle calls `SettingsCubit.setAnalyticsEnabled`,
///   which flips the AnalyticsBuffer gate and purges the pending
///   on-disk queue on opt-out.
/// - The crash reporting toggle dispatches consent events on the
///   existing `CrashConsentBloc` — no parallel consent state is
///   introduced. (See `SettingsCubit.setCrashReporting`.)
/// - Privacy Policy / Terms links open in the system browser via
///   `url_launcher`; when no browser can be resolved we fall back to
///   copying the URL to the clipboard so the user is never stranded.
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key, this.launcher});

  /// Test-only URL-launcher injection. Real builds use `launchUrl`
  /// from `package:url_launcher`. Widget tests pass a fake so they
  /// don't need to stub the platform channel.
  @visibleForTesting
  final UrlLauncher? launcher;

  static const String _privacyPolicyUrl =
      'https://learn.REDACTED-BRAND-DOMAIN/privacy';
  static const String _termsUrl =
      'https://learn.REDACTED-BRAND-DOMAIN/terms';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & data')),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('settings.privacy.analytics'),
            secondary: const Icon(Icons.analytics_outlined),
            title: const Text('Share usage analytics'),
            subtitle: const Text(
              'Structural events only — what you tapped, never what you '
              'typed. Turn off to drop pending data and stop collection.',
            ),
            value: state.analyticsEnabled,
            onChanged: cubit.setAnalyticsEnabled,
          ),
          const Divider(height: 0),
          SwitchListTile(
            key: const Key('settings.privacy.crashReporting'),
            secondary: const Icon(Icons.bug_report_outlined),
            title: const Text('Share crash reports'),
            subtitle: const Text(
              'Sends anonymised error info when the app crashes so we '
              'can fix bugs. Never includes what you typed.',
            ),
            value: state.crashReportingEnabled,
            onChanged: cubit.setCrashReporting,
          ),
          const Divider(),
          // Slice P8 — GDPR "right of access" surface. Lives here
          // (inside Privacy & data) rather than under Security because
          // it's about the data we hold, not credential protection.
          ListTile(
            key: const Key('settings.privacy.exportData'),
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export my data'),
            subtitle: const Text(
              'Download a JSON copy of your profile, activity, and '
              'enrollments. Available once per day.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => GoRouter.of(context).push('/profile/export'),
          ),
          const Divider(),
          _LinkTile(
            keyValue: const Key('settings.privacy.privacyPolicy'),
            title: 'Privacy Policy',
            url: _privacyPolicyUrl,
            launcher: launcher,
          ),
          _LinkTile(
            keyValue: const Key('settings.privacy.terms'),
            title: 'Terms of Service',
            url: _termsUrl,
            launcher: launcher,
          ),
        ],
      ),
    );
  }
}

/// External-URL tile. Tap launches the system browser; on failure
/// (no browser resolvable, or the launch is rejected for any reason)
/// falls back to copying the URL to the clipboard so the user can
/// paste it wherever they like. Launch is routed through the override
/// [launcher] when provided — tests use that to inject a fake without
/// having to hit the platform channel.
typedef UrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

Future<bool> _defaultLaunch(Uri url, {LaunchMode mode = LaunchMode.externalApplication}) =>
    launchUrl(url, mode: mode);

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.keyValue,
    required this.title,
    required this.url,
    this.launcher,
  });

  final Key keyValue;
  final String title;
  final String url;
  final UrlLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: keyValue,
      leading: const Icon(Icons.open_in_new_rounded),
      title: Text(title),
      subtitle: Text(
        url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _handleTap(context),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final uri = Uri.parse(url);
    final launch = launcher ?? _defaultLaunch;
    bool launched = false;
    try {
      launched = await launch(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched) return;
    // Fallback: copy to clipboard so the user isn't stranded on a
    // tile that does nothing (e.g. a locked-down device with no
    // browser).
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $url'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
