import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P7a — disable TOTP.
///
/// Requires current password AND a current 6-digit code (matches the
/// server's `DELETE /api/me/mfa/totp` gate). Framed as a destructive
/// action with the error colour on the submit button.
class MfaTotpDisableScreen extends StatefulWidget {
  const MfaTotpDisableScreen({required this.meRepo, super.key});

  final MeRepository meRepo;

  @override
  State<MfaTotpDisableScreen> createState() => _MfaTotpDisableScreenState();
}

class _MfaTotpDisableScreenState extends State<MfaTotpDisableScreen> {
  final _pwCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pw = _pwCtrl.text;
    final code = _codeCtrl.text.trim();
    if (pw.isEmpty || code.length != 6) {
      setState(() =>
          _error = 'Enter your password and a current 6-digit code.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.meRepo.disableTotp(currentPassword: pw, code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('mfaDisable.successToast'),
          content: Text('Two-factor authentication disabled'),
        ),
      );
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
        _error = e.statusCode == 401
            ? 'Wrong password or code.'
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Disable two-factor')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Disabling two-factor authentication weakens your account '
                    'security. You can re-enrol any time from your profile.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                key: const Key('mfaDisable.password'),
                controller: _pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('mfaDisable.code'),
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  key: const Key('mfaDisable.error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('mfaDisable.submit'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Disable two-factor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
