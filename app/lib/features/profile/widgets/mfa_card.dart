import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/mfa.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P7a + P7b — "Two-factor authentication" ListTile-ish card for
/// the profile screen's Account section.
///
/// Live read of `GET /api/me/mfa`:
///   - No factors          → "Set up" action → TOTP enrol route.
///   - TOTP only           → status + "Disable" → TOTP disable.
///   - Passkeys only       → "N passkeys · Manage" → passkeys list.
///   - TOTP + passkeys     → multi-line summary + "Manage" → passkeys list.
///
/// The card is intentionally a single row; richer management happens
/// on the dedicated TOTP / passkey screens so the profile stays tidy.
class MfaCard extends StatefulWidget {
  const MfaCard({required this.meRepo, super.key});
  final MeRepository meRepo;

  @override
  State<MfaCard> createState() => _MfaCardState();
}

class _MfaCardState extends State<MfaCard> {
  MfaMethods? _methods;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.meRepo.fetchMfaMethods();
      if (!mounted) return;
      setState(() {
        _methods = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load two-factor status.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        key: Key('profile.mfa.loading'),
        leading: Icon(Icons.shield_outlined),
        title: Text('Two-factor authentication'),
        subtitle: Text('Loading…'),
      );
    }
    if (_error != null) {
      return ListTile(
        key: const Key('profile.mfa.error'),
        leading: const Icon(Icons.shield_outlined),
        title: const Text('Two-factor authentication'),
        subtitle: Text(_error!),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      );
    }
    final m = _methods!;
    if (!m.totp && m.webauthnCount == 0) {
      return ListTile(
        key: const Key('profile.mfa.setup'),
        leading: const Icon(Icons.shield_outlined),
        title: const Text('Two-factor authentication'),
        subtitle: const Text('Off — set up an authenticator or passkey'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          // Offer a picker between TOTP and passkey. Keeping the
          // decision on a follow-up screen avoids doubling the size of
          // this tile for every profile render.
          await _pickFactor(context);
          if (mounted) _load();
        },
      );
    }
    // At least one factor enrolled.
    final summary = _summaryFor(m);
    return ListTile(
      key: const Key('profile.mfa.manage'),
      leading: const Icon(Icons.shield, color: Colors.green),
      title: const Text('Two-factor authentication'),
      subtitle: Text(summary),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        // Prefer the passkeys list when passkeys are present — it also
        // offers "Add another passkey" so the user can grow their set
        // without coming back to the profile. Otherwise fall back to
        // the TOTP disable screen (legacy P7a behaviour).
        if (m.webauthnCount > 0) {
          await GoRouter.of(context).push('/profile/security/mfa/passkeys');
        } else {
          await GoRouter.of(context)
              .push('/profile/security/mfa/totp/disable');
        }
        if (mounted) _load();
      },
    );
  }

  String _summaryFor(MfaMethods m) {
    final parts = <String>[];
    if (m.totp) parts.add('Authenticator app');
    if (m.webauthnCount > 0) {
      parts.add(
        m.webauthnCount == 1 ? '1 passkey' : '${m.webauthnCount} passkeys',
      );
    }
    final head = parts.join(' · ');
    if (m.backupCodesRemaining > 0) {
      return '$head · ${m.backupCodesRemaining} backup codes left';
    }
    return head;
  }

  Future<void> _pickFactor(BuildContext context) async {
    // Capture the router up-front so we don't need `context` after the
    // await — avoids the `use_build_context_synchronously` lint while
    // still reading the right GoRouter instance for this navigator.
    final router = GoRouter.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('profile.mfa.picker.totp'),
                leading: const Icon(Icons.password),
                title: const Text('Authenticator app (TOTP)'),
                subtitle: const Text('Six-digit codes from an app you trust'),
                onTap: () => Navigator.of(ctx).pop('totp'),
              ),
              ListTile(
                key: const Key('profile.mfa.picker.passkey'),
                leading: const Icon(Icons.fingerprint),
                title: const Text('Passkey'),
                subtitle:
                    const Text("Use your device's biometrics or screen lock"),
                onTap: () => Navigator.of(ctx).pop('passkey'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'totp') {
      await router.push('/profile/security/mfa/totp/enrol');
    } else {
      await router.push('/profile/security/mfa/passkey/enrol');
    }
  }
}
