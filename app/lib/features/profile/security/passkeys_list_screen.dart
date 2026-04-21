import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/webauthn.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P7b — lists the caller's registered passkeys and hosts the
/// per-row delete flow.
///
/// The delete action requires the current password (P5 / P7a posture).
/// A confirmation sheet collects it inline so the user doesn't have to
/// leave the screen; on success we refetch the list.
class PasskeysListScreen extends StatefulWidget {
  const PasskeysListScreen({required this.meRepo, super.key});

  final MeRepository meRepo;

  @override
  State<PasskeysListScreen> createState() => _PasskeysListScreenState();
}

class _PasskeysListScreenState extends State<PasskeysListScreen> {
  List<WebauthnCredential>? _creds;
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
      final list = await widget.meRepo.fetchWebauthnCredentials();
      if (!mounted) return;
      setState(() {
        _creds = list;
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
        _error = 'Could not load passkeys.';
      });
    }
  }

  Future<void> _delete(WebauthnCredential cred) async {
    final pw = await _promptCurrentPassword();
    if (pw == null) return; // cancelled
    try {
      await widget.meRepo.deleteWebauthnCredential(
        credentialId: cred.id,
        currentPassword: pw,
      );
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 401
                ? 'Wrong password — passkey was NOT deleted.'
                : e.message,
          ),
        ),
      );
    }
  }

  Future<String?> _promptCurrentPassword() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          key: const Key('passkeys.deleteDialog'),
          title: const Text('Confirm with your password'),
          content: TextField(
            key: const Key('passkeys.deletePwInput'),
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('passkeys.deleteCancel'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('passkeys.deleteConfirm'),
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (result == null || result.isEmpty) return null;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Passkeys')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorBody(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      key: const Key('passkeys.list'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if ((_creds ?? []).isEmpty)
                          _EmptyState(theme: theme)
                        else
                          for (final cred in _creds!)
                            _PasskeyTile(
                              cred: cred,
                              onDelete: () => _delete(cred),
                            ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('passkeys.addAnother'),
                          onPressed: () async {
                            await GoRouter.of(context)
                                .push('/profile/security/mfa/passkey/enrol');
                            if (mounted) await _load();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add another passkey'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _PasskeyTile extends StatelessWidget {
  const _PasskeyTile({required this.cred, required this.onDelete});

  final WebauthnCredential cred;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = cred.label ?? 'Unnamed passkey';
    return Card(
      key: Key('passkeys.tile.${cred.id}'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.key),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: Key('passkeys.delete.${cred.id}'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete passkey',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Created ${_formatDate(cred.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (cred.lastUsedAt != null)
              Text(
                'Last used ${_formatRelative(cred.lastUsedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            if (cred.transports.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in cred.transports)
                    Chip(
                      label: Text(_prettyTransport(t)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _prettyTransport(String t) {
    switch (t.toLowerCase()) {
      case 'usb':
        return 'USB';
      case 'nfc':
        return 'NFC';
      case 'ble':
        return 'Bluetooth';
      case 'internal':
        return 'This device';
      case 'hybrid':
        return 'Phone link';
      default:
        return t;
    }
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)}';
  }

  String _pad(int n) => n < 10 ? '0$n' : '$n';

  String _formatRelative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return 'on ${_formatDate(d)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('passkeys.empty'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.key_off_outlined,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'No passkeys registered yet.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
