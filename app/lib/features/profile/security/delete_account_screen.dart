import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_bloc.dart';
import '../../../core/auth/auth_event.dart';
import '../../../core/http/error_envelope.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P5 — Delete account.
///
/// Two-step confirmation:
///   1. Warning card + "Export my data first" button (disabled for now
///      because P8 hasn't landed) + acknowledgement checkbox + Continue.
///   2. Password re-entry + destructive "Delete my account" button.
///
/// On success: dispatch `LoggedOut` to the AuthBloc (clears tokens +
/// demotes the router to `/login`) and show a reassurance SnackBar.
/// Wrong-password surfaces as an inline error so the user can retry.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({required this.meRepo, super.key});

  final MeRepository meRepo;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

enum _Step { warning, confirm }

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  _Step _step = _Step.warning;

  // Step 1 state.
  bool _acknowledged = false;

  // Step 2 state.
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (_passwordError != null || _generalError != null) {
      setState(() {
        _passwordError = null;
        _generalError = null;
      });
    } else {
      // Still refresh to re-enable the submit button.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_passwordCtrl.text.isEmpty) return;

    setState(() {
      _submitting = true;
      _passwordError = null;
      _generalError = null;
    });

    try {
      await widget.meRepo.deleteAccount(
        currentPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      // Tell the auth bloc to log out (clears tokens, demotes state).
      // The router's refreshListenable will bounce us to /login.
      context.read<AuthBloc>().add(const LoggedOut());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('deleteAccount.successToast'),
          content: Text(
            'Account deleted. You have 30 days to contact support to restore it.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      // Belt and braces: navigate explicitly in case the redirect rule
      // hasn't fired yet by the time this frame commits.
      GoRouter.of(context).go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (e.statusCode == 401) {
          _passwordError = 'Password is incorrect';
        } else if (e.statusCode == 429) {
          _generalError =
              'Too many attempts — wait a few minutes before trying again.';
        } else {
          _generalError = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _generalError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _step == _Step.warning
              ? _buildWarningStep(context)
              : _buildConfirmStep(context),
        ),
      ),
    );
  }

  Widget _buildWarningStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('deleteAccount.step.warning'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delete your account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account will be marked for deletion. You have '
                  '30 days to contact support to restore it; after that, '
                  'it is permanently removed and cannot be recovered.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your learning progress, attempts, and uploaded '
                  'content will be erased along with the account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // P8 landed — the button now routes to /profile/export where
        // the user can download a JSON snapshot before hitting the
        // irreversible delete path. The GDPR "right of erasure"
        // supersedes "right of access" for already-deleted accounts,
        // so exporting AFTER deletion is rejected server-side; this
        // button is the recommended on-ramp to get data out first.
        OutlinedButton.icon(
          key: const Key('deleteAccount.exportFirst'),
          onPressed: () => GoRouter.of(context).push('/profile/export'),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export my data first'),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          key: const Key('deleteAccount.acknowledge'),
          value: _acknowledged,
          onChanged: (v) => setState(() => _acknowledged = v ?? false),
          title: const Text(
            'I understand this is not reversible after 30 days.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('deleteAccount.continue'),
          onPressed: _acknowledged
              ? () => setState(() => _step = _Step.confirm)
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('deleteAccount.step.confirm'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter your password to confirm deletion.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('deleteAccount.password'),
          controller: _passwordCtrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            errorText: _passwordError,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        if (_generalError != null) ...[
          Text(
            _generalError!,
            key: const Key('deleteAccount.generalError'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          key: const Key('deleteAccount.submit'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed:
              (_passwordCtrl.text.isEmpty || _submitting) ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete my account'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('deleteAccount.back'),
          onPressed:
              _submitting ? null : () => setState(() => _step = _Step.warning),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
