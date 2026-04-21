import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/auth/auth_state.dart';

/// Slice P7a — second-step MFA challenge after a password-correct
/// `POST /api/auth/login` returns `mfaPending`.
///
/// The bloc holds the pending token; this screen only collects a
/// 6-digit TOTP code (default) or a backup code (toggle link) and
/// dispatches [MfaSubmitted].
///
/// A valid code transitions the bloc into `Authenticated` and the
/// router's redirect rule bounces the user to their role home. A
/// wrong code keeps the screen on-stage with an inline error.
class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _ctrl = TextEditingController();
  bool _useBackup = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    context.read<AuthBloc>().add(
          MfaSubmitted(code: code, useBackup: _useBackup),
        );
  }

  void _toggleBackup() {
    setState(() {
      _useBackup = !_useBackup;
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // Once the challenge resolves (success → Authenticated, cancel →
      // Unauthenticated) this screen should pop. The login screen sits
      // underneath on the stack and the router redirect will take over
      // on `Authenticated`.
      listenWhen: (prev, next) =>
          next is Authenticated || next is Unauthenticated,
      listener: (context, state) {
        final router = GoRouter.of(context);
        if (router.canPop()) router.pop();
      },
      builder: (context, state) {
        final challenge =
            state is MfaChallengeRequired ? state : null;
        if (challenge == null) {
          // Likely a brief transitional frame between submit → Authenticated;
          // render a placeholder instead of crashing.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final theme = Theme.of(context);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            // Cancel the challenge (discards the pending token, returns
            // to Unauthenticated) and pop. The listener above picks up
            // the Unauthenticated state.
            context.read<AuthBloc>().add(const MfaChallengeAborted());
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_useBackup ? 'Backup code' : 'Two-factor code'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context
                      .read<AuthBloc>()
                      .add(const MfaChallengeAborted());
                },
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _useBackup
                        ? 'Enter one of the backup codes you saved during setup. Each code can only be used once.'
                        : 'Open your authenticator app and enter the current 6-digit code.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: Key(
                      _useBackup ? 'mfa.backupInput' : 'mfa.totpInput',
                    ),
                    controller: _ctrl,
                    keyboardType: _useBackup
                        ? TextInputType.text
                        : TextInputType.number,
                    inputFormatters: _useBackup
                        ? null
                        : <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: _useBackup ? 2 : 8,
                    ),
                    autofocus: true,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: _useBackup ? 'ABCDE-12345' : '••••••',
                      errorText: challenge.errorMessage,
                    ),
                    onSubmitted: (_) => _submit(context),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('mfa.submit'),
                    onPressed:
                        challenge.submitting ? null : () => _submit(context),
                    child: challenge.submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                  const SizedBox(height: 12),
                  // Slice P7b — offer the passkey path when the server
                  // advertised `"webauthn"`. Tapping dispatches a
                  // single event; the bloc runs the Credential Manager
                  // prompt + the server exchange under the hood.
                  if (challenge.availableMethods.contains('webauthn'))
                    OutlinedButton.icon(
                      key: const Key('mfa.usePasskey'),
                      onPressed: challenge.submitting
                          ? null
                          : () => context
                              .read<AuthBloc>()
                              .add(const MfaPasskeySubmitted()),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use passkey or security key'),
                    ),
                  if (challenge.availableMethods.contains('webauthn'))
                    const SizedBox(height: 8),
                  // Only offer the backup-code switch when the server
                  // advertised `"backup"` in availableMethods.
                  if (challenge.availableMethods.contains('backup'))
                    TextButton(
                      key: const Key('mfa.toggleBackup'),
                      onPressed: _toggleBackup,
                      child: Text(
                        _useBackup
                            ? 'Use authenticator code instead'
                            : 'Use a backup code instead',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
