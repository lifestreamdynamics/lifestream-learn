import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/crash/crash_consent_bloc.dart';

/// One-shot screen shown the first time a user reaches the authed
/// section of the app. Explains what crash reports contain and lets
/// the learner grant or deny consent. The decision is persisted — this
/// screen does not reappear unless storage is cleared (e.g. reinstall).
///
/// Navigation out of this screen is driven by the router redirect in
/// `app_router.dart`: the router's `refreshListenable` watches the
/// [CrashConsentBloc] stream, and when the bloc emits `granted` or
/// `denied` the redirect rule bounces the user to their role home.
/// This screen does NOT call `context.go(...)` itself — a race between
/// an explicit nav and the redirect produced a visible double-push.
class CrashConsentScreen extends StatelessWidget {
  const CrashConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.bug_report_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Help us fix crashes',
                key: const Key('crashConsent.title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'When the app crashes, we can send an anonymous '
                'report to our team so we can fix the bug.\n\n'
                'Reports include the error name, stack trace, your '
                'device platform and OS version, and a short breadcrumb '
                'of screens you visited — nothing you typed, no '
                'account details, and no learning progress.',
                key: Key('crashConsent.body'),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                key: const Key('crashConsent.allow'),
                onPressed: () => context
                    .read<CrashConsentBloc>()
                    .add(const CrashConsentGranted()),
                child: const Text('Allow crash reports'),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('crashConsent.deny'),
                onPressed: () => context
                    .read<CrashConsentBloc>()
                    .add(const CrashConsentRevoked()),
                child: const Text('Not now'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
