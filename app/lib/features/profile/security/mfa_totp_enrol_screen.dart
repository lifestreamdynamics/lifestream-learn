import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/mfa.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P7a — TOTP enrolment wizard.
///
/// Three steps, each rendered by a separate widget tree on the same
/// scaffold so the back-stack stays shallow (a single /profile pop
/// returns to the profile screen from any step):
///
///   1. Scan — show the QR code + the manual secret + copy button.
///   2. Verify — collect a 6-digit code + optional device label.
///   3. Backup — show plaintext codes ONCE; user must acknowledge
///      they've saved them before leaving.
///
/// On any terminal exit (back-button, Done, or a navigation out) we
/// drop the secret from memory — it was held only inside the
/// `TotpEnrolmentStart` instance.
class MfaTotpEnrolScreen extends StatefulWidget {
  const MfaTotpEnrolScreen({required this.meRepo, super.key});

  final MeRepository meRepo;

  @override
  State<MfaTotpEnrolScreen> createState() => _MfaTotpEnrolScreenState();
}

enum _EnrolStep { scan, verify, backup }

class _MfaTotpEnrolScreenState extends State<MfaTotpEnrolScreen> {
  _EnrolStep _step = _EnrolStep.scan;

  TotpEnrolmentStart? _enrolment;
  List<String>? _backupCodes;
  String? _error;
  bool _loading = false;

  // Verify step inputs.
  final _codeCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  String? _codeError;

  // Backup step.
  bool _acknowledgedBackup = false;

  @override
  void initState() {
    super.initState();
    _startEnrol();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _startEnrol() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.meRepo.startTotpEnrol();
      if (!mounted) return;
      setState(() {
        _enrolment = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.statusCode == 409) {
          _error =
              'Two-factor authentication is already set up. Disable it first to re-enrol.';
        } else {
          _error = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not start enrolment. Please try again.';
      });
    }
  }

  Future<void> _confirm() async {
    final enrolment = _enrolment;
    if (enrolment == null) return;
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _codeError = 'Code must be 6 digits');
      return;
    }
    setState(() {
      _loading = true;
      _codeError = null;
    });
    try {
      final label = _labelCtrl.text.trim();
      final res = await widget.meRepo.confirmTotpEnrol(
        pendingToken: enrolment.pendingEnrolmentToken,
        code: code,
        label: label.isEmpty ? null : label,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _backupCodes = res.backupCodes;
        _step = _EnrolStep.backup;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.statusCode == 401) {
          _codeError = 'Wrong code — try again';
        } else if (e.statusCode == 409) {
          _error = 'Two-factor authentication is already set up.';
        } else {
          _error = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBody(
                    message: _error!,
                    onRetry: _startEnrol,
                    onCancel: _finish,
                  )
                : _bodyFor(_step),
      ),
    );
  }

  String _titleFor(_EnrolStep step) {
    switch (step) {
      case _EnrolStep.scan:
        return 'Scan QR code';
      case _EnrolStep.verify:
        return 'Verify code';
      case _EnrolStep.backup:
        return 'Save backup codes';
    }
  }

  Widget _bodyFor(_EnrolStep step) {
    switch (step) {
      case _EnrolStep.scan:
        return _ScanStep(
          enrolment: _enrolment,
          onContinue: () => setState(() => _step = _EnrolStep.verify),
        );
      case _EnrolStep.verify:
        return _VerifyStep(
          codeCtrl: _codeCtrl,
          labelCtrl: _labelCtrl,
          codeError: _codeError,
          onSubmit: _confirm,
          onBack: () => setState(() => _step = _EnrolStep.scan),
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

class _ScanStep extends StatelessWidget {
  const _ScanStep({required this.enrolment, required this.onContinue});

  final TotpEnrolmentStart? enrolment;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final enrolment = this.enrolment;
    if (enrolment == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Open an authenticator app (Authy, Google Authenticator, 1Password, …) '
            'and scan this code.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Center(
            child: _QrImage(
              key: const Key('mfaEnrol.qr'),
              dataUrl: enrolment.qrDataUrl,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Or enter this secret manually:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  enrolment.secret,
                  key: const Key('mfaEnrol.secret'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                key: const Key('mfaEnrol.copySecret'),
                icon: const Icon(Icons.copy),
                tooltip: 'Copy secret',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: enrolment.secret));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 1),
                      content: Text('Secret copied'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('mfaEnrol.continueToVerify'),
            onPressed: onContinue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _VerifyStep extends StatelessWidget {
  const _VerifyStep({
    required this.codeCtrl,
    required this.labelCtrl,
    required this.codeError,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController codeCtrl;
  final TextEditingController labelCtrl;
  final String? codeError;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the 6-digit code your authenticator app is showing.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('mfaEnrol.codeInput'),
            controller: codeCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: InputDecoration(
              labelText: '6-digit code',
              border: const OutlineInputBorder(),
              errorText: codeError,
            ),
            autofocus: true,
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('mfaEnrol.labelInput'),
            controller: labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              helperText: 'e.g. "iPhone Authenticator" — shown in your settings.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('mfaEnrol.submit'),
            onPressed: onSubmit,
            child: const Text('Verify'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('mfaEnrol.backToScan'),
            onPressed: onBack,
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

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
            key: const Key('mfaEnrol.backupWarning'),
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
                    'sign in if you lose access to your authenticator.',
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
            key: const Key('mfaEnrol.backupCodes'),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('mfaEnrol.copyAll'),
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
              ),
            ],
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            key: const Key('mfaEnrol.ackCheckbox'),
            title: const Text('I have saved these codes'),
            value: acknowledged,
            onChanged: onAcknowledgedChanged,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('mfaEnrol.done'),
            onPressed: acknowledged ? onDone : null,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// Renders a `data:image/png;base64,...` QR payload from the server.
/// Stripping the prefix keeps us off the `qr_flutter` dep — the
/// server already produced the PNG during enrolment.
class _QrImage extends StatelessWidget {
  const _QrImage({required this.dataUrl, super.key});
  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    // Expected prefix `data:image/png;base64,`. Tolerant parsing so a
    // raw base64 payload (no prefix) still renders — future-proofs the
    // client against a server that swaps formats.
    final comma = dataUrl.indexOf(',');
    final payload = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
    Uint8List bytes;
    try {
      bytes = base64Decode(payload);
    } catch (_) {
      return const _QrErrorPlaceholder();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 256, maxHeight: 256),
      child: Image.memory(
        bytes,
        gaplessPlayback: true,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _QrErrorPlaceholder(),
      ),
    );
  }
}

class _QrErrorPlaceholder extends StatelessWidget {
  const _QrErrorPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      height: 256,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, size: 48),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
