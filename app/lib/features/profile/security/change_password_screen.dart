import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P5 — Change password.
///
/// Three fields (current / new / confirm) with inline validation. The
/// submit button stays disabled until the form validates (current
/// non-empty; new >= 12 chars and != current; confirm == new). On
/// success, show a SnackBar and pop back to the profile. On 401 (wrong
/// current password), surface an inline error under that field. On 429,
/// surface a friendly rate-limit message.
///
/// The server invalidates all existing refresh tokens on success via the
/// `passwordChangedAt` mechanism; the next refresh will log the user
/// out naturally. We do NOT force a logout here — the access token is
/// still valid for its remaining TTL and the user just explicitly proved
/// knowledge of their password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({required this.meRepo, super.key});

  final MeRepository meRepo;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const int _minNewPasswordLength = 12;

  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _submitting = false;
  String? _currentPasswordError;
  String? _generalError;

  // Drives the submit-button disabled state. Recomputed on every text
  // change via setState so the button flips live with the form.
  bool get _formValid {
    final cur = _currentCtrl.text;
    final nw = _newCtrl.text;
    final conf = _confirmCtrl.text;
    if (cur.isEmpty) return false;
    if (nw.length < _minNewPasswordLength) return false;
    if (nw == cur) return false;
    if (conf != nw) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_currentCtrl, _newCtrl, _confirmCtrl]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() {
    // Clear any prior server-side error the moment the user edits the
    // relevant field. Otherwise the inline "Current password is
    // incorrect" would linger after they start typing a fresh attempt.
    if (_currentPasswordError != null || _generalError != null) {
      setState(() {
        _currentPasswordError = null;
        _generalError = null;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (!_formValid) return;

    setState(() {
      _submitting = true;
      _currentPasswordError = null;
      _generalError = null;
    });

    try {
      await widget.meRepo.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('changePassword.successToast'),
          content: Text('Password updated'),
        ),
      );
      // Pop back to profile. If we were launched as the root route
      // (e.g. deep link), just fall back to /profile.
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/profile');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (e.statusCode == 401) {
          _currentPasswordError = 'Current password is incorrect';
        } else if (e.statusCode == 429) {
          _generalError =
              'Too many attempts — wait a few minutes before trying again.';
        } else {
          _generalError = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _generalError = 'Something went wrong. Please try again.';
      });
    }
  }

  String? _validateCurrent(String? v) {
    if ((v ?? '').isEmpty) return 'Enter your current password';
    return null;
  }

  String? _validateNew(String? v) {
    final s = v ?? '';
    if (s.length < _minNewPasswordLength) {
      return 'Must be at least $_minNewPasswordLength characters';
    }
    if (s == _currentCtrl.text) {
      return 'New password must differ from current';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '') != _newCtrl.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('changePassword.current'),
                  controller: _currentCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    border: const OutlineInputBorder(),
                    errorText: _currentPasswordError,
                  ),
                  validator: _validateCurrent,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('changePassword.new'),
                  controller: _newCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    helperText:
                        'At least $_minNewPasswordLength characters, different from your current one.',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _validateNew,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('changePassword.confirm'),
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                if (_generalError != null) ...[
                  Text(
                    _generalError!,
                    key: const Key('changePassword.generalError'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  key: const Key('changePassword.submit'),
                  onPressed: (!_formValid || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
