import 'package:flutter/material.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/session.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P6 — Active sessions screen.
///
/// Shows one tile per row in `GET /api/me/sessions`, newest first. Each
/// tile carries a device icon derived from `deviceLabel`, a relative
/// "last seen" string, and — for non-current rows — an overflow menu
/// with "Sign out this device". The current session is labelled "You're
/// signed in here" instead of showing an action.
///
/// Pull-to-refresh is wired to the same `listSessions()` call. A
/// footer button runs `revokeAllOtherSessions()`, disabled while the
/// list has <= 1 row (nothing to sign out) or while another mutation
/// is in flight.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({required this.meRepo, super.key});

  final MeRepository meRepo;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Session>? _sessions;
  String? _loadError;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.meRepo.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _sessions = _sessions ?? const <Session>[];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load sessions';
        _sessions = _sessions ?? const <Session>[];
      });
    }
  }

  Future<void> _revokeOne(Session session) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await widget.meRepo.revokeSession(session.id);
      if (!mounted) return;
      // Reload from the server so the list reflects truth. We could
      // optimistically strip the row instead, but a fresh fetch also
      // updates `lastSeenAt` values on the remaining rows — cheap and
      // the user is already waiting on a tap response.
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('sessions.revokeOneToast'),
          content: Text('Signed out of that device'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _revokeAllOthers() async {
    if (_mutating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('sessions.revokeAllDialog'),
        title: const Text('Sign out all other devices?'),
        content: const Text(
          'Other devices will need to sign in again. This session stays signed in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('sessions.revokeAllConfirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out others'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _mutating = true);
    try {
      await widget.meRepo.revokeAllOtherSessions();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('sessions.revokeAllToast'),
          content: Text('Signed out of all other devices'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    final count = sessions?.length ?? 0;
    final hasOthers = count > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Active sessions')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: sessions == null
              ? const _LoadingList()
              : sessions.isEmpty
                  ? _EmptyState(errorMessage: _loadError)
                  : ListView.separated(
                      key: const Key('sessions.list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, i) {
                        final s = sessions[i];
                        return _SessionTile(
                          session: s,
                          onRevoke: (_mutating || s.current)
                              ? null
                              : () => _revokeOne(s),
                        );
                      },
                    ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.tonalIcon(
            key: const Key('sessions.revokeAll'),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out all other devices'),
            onPressed: (_mutating || !hasOthers) ? null : _revokeAllOthers,
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onRevoke});

  final Session session;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForLabel(session.deviceLabel);
    final label = session.deviceLabel ?? 'Unknown device';
    final subtitle = session.current
        ? "You're signed in here"
        : _relativeLastSeen(session.lastSeenAt);

    final trailing = session.current
        ? null
        : PopupMenuButton<String>(
            key: Key('sessions.tile.${session.id}.menu'),
            onSelected: (v) {
              if (v == 'revoke') onRevoke?.call();
            },
            enabled: onRevoke != null,
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'revoke',
                child: Text('Sign out this device'),
              ),
            ],
          );

    return ListTile(
      key: Key('sessions.tile.${session.id}'),
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        subtitle,
        style: session.current
            ? theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              )
            : null,
      ),
      trailing: trailing,
    );
  }

  static IconData _iconForLabel(String? label) {
    if (label == null) return Icons.devices_other_outlined;
    switch (label) {
      case 'Android':
      case 'iPhone':
        return Icons.phone_android_outlined;
      case 'iPad':
        return Icons.tablet_mac_outlined;
      case 'macOS':
        return Icons.laptop_mac_outlined;
      case 'Windows':
        return Icons.laptop_windows_outlined;
      case 'Linux':
      case 'ChromeOS':
        return Icons.laptop_chromebook_outlined;
      default:
        return Icons.devices_other_outlined;
    }
  }
}

/// Hand-rolled "2 hours ago" formatter. Good enough for a session list;
/// when the app gains `intl` this moves into shared utils and supports
/// localisation. Kept local so we don't pull another dep for one string.
String _relativeLastSeen(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when.toLocal());
  if (diff.inSeconds < 60) return 'Active now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? '1 minute ago' : '$m minutes ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return d == 1 ? '1 day ago' : '$d days ago';
  }
  if (diff.inDays < 30) {
    final w = diff.inDays ~/ 7;
    return w == 1 ? '1 week ago' : '$w weeks ago';
  }
  final months = diff.inDays ~/ 30;
  return months == 1 ? '1 month ago' : '$months months ago';
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('sessions.loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('sessions.empty'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.devices_other_outlined,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            errorMessage ?? 'No active sessions',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            errorMessage == null
                ? 'Pull down to refresh.'
                : 'Pull down to try again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
