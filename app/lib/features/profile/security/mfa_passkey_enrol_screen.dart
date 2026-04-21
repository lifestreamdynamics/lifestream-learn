import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/passkey_platform.dart';
import '../../../core/http/error_envelope.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P7b — passkey enrolment wizard.
///
/// Three-screen flow (same backbone as the TOTP enrol wizard):
///   1. Intro — explain what a passkey is + offer a label field.
///   2. Platform prompt — in-flight while the Credential Manager runs
///      the system UI. On return we immediately POST the attestation
///      to `/register/verify`.
///   3. Backup — if the server returned fresh backup codes (first MFA
///      enrolment on this account), show them once with the same
///      acknowledge-checkbox gate as the TOTP flow.
///
/// We explicitly do NOT persist the credentialId client-side — it
/// lives on the server under `MfaCredential.credentialId` and the
/// passkey itself is stored by the platform. The client just needs to
/// know "registration succeeded; server state is fresh".
class MfaPasskeyEnrolScreen extends StatefulWidget {
  const MfaPasskeyEnrolScreen({
    required this.meRepo,
    this.passkeyPlatform,
    super.key,
  });

  final MeRepository meRepo;

  /// Injected in tests; production falls back to a default instance.
  final PasskeyPlatform? passkeyPlatform;

  @override
  State<MfaPasskeyEnrolScreen> createState() => _MfaPasskeyEnrolScreenState();
}

enum _EnrolStep { intro, backup }

class _MfaPasskeyEnrolScreenState extends State<MfaPasskeyEnrolScreen> {
  late final PasskeyPlatform _platform =
      widget.passkeyPlatform ?? PasskeyPlatform();

  _EnrolStep _step = _EnrolStep.intro;
  bool _submitting = false;
  String? _error;
  List<String>? _backupCodes;
  bool _acknowledgedBackup = false;
  final _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_platform.isSupported) {
      setState(() {
        _error = 'Passkeys are not supported on this device.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final opts = await widget.meRepo.startWebauthnRegistration();
      final attestation = await _platform.register(opts.options);
      final result = await widget.meRepo.verifyWebauthnRegistration(
        pendingToken: opts.pendingToken,
        attestationResponse: attestation,
        label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
      );
      if (!mounted) return;
      final backupCodes = result['backupCodes'];
      setState(() {
        _submitting = false;
        if (backupCodes is List) {
          _backupCodes = backupCodes.cast<String>();
          _step = _EnrolStep.backup;
        } else {
          // No backup codes — user already had MFA. Pop back to the
          // caller so the list screen refreshes.
          _finish();
        }
      });
    } on PasskeyCancelledException {
      // User tapped cancel in the system UI. Silently return to the
      // intro step so they can retry or back out.
      if (!mounted) return;
      setState(() => _submitting = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (e.statusCode == 409) {
          _error = 'This passkey is already registered on your account.';
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not register passkey: $e';
      });
    }
  }

  void _finish() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(_step))),
      body: SafeArea(
        child: _submitting
            ? const Center(child: CircularProgressIndicator())
            : _bodyFor(_step),
      ),
    );
  }

  String _titleFor(_EnrolStep step) {
    switch (step) {
      case _EnrolStep.intro:
        return 'Add a passkey';
      case _EnrolStep.backup:
        return 'Save backup codes';
    }
  }

  Widget _bodyFor(_EnrolStep step) {
    switch (step) {
      case _EnrolStep.intro:
        return _IntroStep(
          labelCtrl: _labelCtrl,
          error: _error,
          onContinue: _start,
          onCancel: _finish,
        );
      case _EnrolStep.backup:
        return _BackupStep(
          codes: _backupCodes ?? const <String>[],
          acknowledged: _acknowledgedBackup,
          onAcknowledgedChanged: (v) =>
              setState(() => _acknowledgedBackup = v ?? false),
          onDone: _finish,
        );
    }
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.labelCtrl,
    required this.error,
    required this.onContinue,
    required this.onCancel,
  });

  final TextEditingController labelCtrl;
  final String? error;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.fingerprint,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Sign in with a passkey',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Passkeys replace the six-digit code with your device’s '
            'fingerprint, face, or screen lock. They’re phishing-'
            'resistant and can sync across your signed-in devices.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('passkeyEnrol.labelInput'),
            controller: labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              helperText: 'e.g. "Pixel fingerprint" — shown in your settings.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (error != null)
            Card(
              key: const Key('passkeyEnrol.errorCard'),
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          if (error != null) const SizedBox(height: 16),
          FilledButton(
            key: const Key('passkeyEnrol.continue'),
            onPressed: onContinue,
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('passkeyEnrol.cancel'),
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Shared backup-codes widget — kept adjacent to the enrolment flow so
/// the dependency graph stays short. Structurally identical to the
/// TOTP backup step from P7a (same safe-to-the-user gate).
class _BackupStep extends StatelessWidget {
  const _BackupStep({
    required this.codes,
    required this.acknowledged,
    required this.onAcknowledgedChanged,
    required this.onDone,
  });

  final List<String> codes;
  final bool acknowledged;
  final ValueChanged<bool?> onAcknowledgedChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            key: const Key('passkeyEnrol.backupWarning'),
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save these codes NOW.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'They are displayed exactly once. Each code can be used to '
                    'sign in if your passkey is unavailable.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            key: const Key('passkeyEnrol.backupCodes'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final code in codes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SelectableText(
                      code,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('passkeyEnrol.copyAll'),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: codes.join('\n')),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  duration: Duration(seconds: 1),
                  content: Text('Codes copied'),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy all'),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            key: const Key('passkeyEnrol.ackCheckbox'),
            title: const Text('I have saved these codes'),
            value: acknowledged,
            onChanged: onAcknowledgedChanged,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('passkeyEnrol.done'),
            onPressed: acknowledged ? onDone : null,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
