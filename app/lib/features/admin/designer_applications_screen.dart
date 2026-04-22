import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/platform/flag_secure.dart';
import '../../data/models/designer_application.dart';
import '../../data/repositories/admin_designer_application_repository.dart';
import '../shared/friendly_error_screen.dart';

/// Admin list of PENDING designer applications. Rows show the
/// applicant's user id (email enrichment is a follow-up once the
/// backend returns joined user data; for today the id is the honest
/// thing we have), the submitted date, and a note preview. Each row
/// has Approve / Reject buttons that open the reviewer-note dialog.
///
/// FLAG_SECURE is enabled while this screen is mounted — the list
/// contains PII (user ids, application notes) that shouldn't be
/// screenshot or show up in Recents.
class DesignerApplicationsScreen extends StatefulWidget {
  const DesignerApplicationsScreen({required this.repo, super.key});

  final AdminDesignerApplicationRepository repo;

  @override
  State<DesignerApplicationsScreen> createState() =>
      _DesignerApplicationsScreenState();
}

class _DesignerApplicationsScreenState
    extends State<DesignerApplicationsScreen> {
  List<DesignerApplication> _items = <DesignerApplication>[];
  bool _loading = true;
  Object? _error;
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    FlagSecure.enable();
    _load();
  }

  @override
  void dispose() {
    FlagSecure.disable();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (!append) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await widget.repo.list(
        status: 'PENDING',
        cursor: append ? _nextCursor : null,
      );
      if (!mounted) return;
      setState(() {
        _items = append ? [..._items, ...page.items] : page.items;
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _decide(DesignerApplication app, AppStatus status) async {
    final note = await _askReviewerNote(context, status: status);
    if (note == null) return; // cancelled
    try {
      await widget.repo.review(
        app.id,
        status: status,
        reviewerNote: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      // Remove from the list — once a row is reviewed it's no longer
      // PENDING, so a fresh page fetch would also drop it. Keep UI
      // responsive by doing it locally.
      setState(() {
        _items = _items.where((x) => x.id != app.id).toList(growable: false);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == AppStatus.approved
                  ? 'Application approved.'
                  : 'Application rejected.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update application: $e')),
      );
    }
  }

  Future<String?> _askReviewerNote(
    BuildContext context, {
    required AppStatus status,
  }) async {
    final controller = TextEditingController();
    final verb = status == AppStatus.approved ? 'Approve' : 'Reject';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('$verb application'),
          content: TextField(
            controller: controller,
            key: Key('admin.reviewerNote.$verb'),
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Reviewer note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: Key('admin.reviewerNote.$verb.confirm'),
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(verb),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Skeletonizer(
        enabled: true,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => const Card(
            child: ListTile(
              title: Text('Placeholder applicant'),
              subtitle: Text('Placeholder note preview — loading…'),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return FriendlyErrorBody(
        title: "Couldn't load applications",
        message: 'The server was unreachable. Try again in a moment.',
        debugError: _error,
        onRetry: _load,
      );
    }
    if (_items.isEmpty) {
      return const Center(
        key: Key('admin.apps.empty'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No pending applications right now.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: const Key('admin.apps.list'),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_nextCursor != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return Center(
              child: TextButton(
                key: const Key('admin.apps.loadMore'),
                onPressed: () => _load(append: true),
                child: const Text('Load more'),
              ),
            );
          }
          final app = _items[index];
          return _ApplicationTile(
            key: Key('admin.apps.tile.${app.id}'),
            application: app,
            onApprove: () => _decide(app, AppStatus.approved),
            onReject: () => _decide(app, AppStatus.rejected),
          );
        },
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({
    required this.application,
    required this.onApprove,
    required this.onReject,
    super.key,
  });

  final DesignerApplication application;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  String _preview(String? note) {
    if (note == null || note.isEmpty) return '(no note)';
    if (note.length <= 100) return note;
    return '${note.substring(0, 100)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Applicant: ${application.userId}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Submitted ${_fmtDate(application.submittedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(_preview(application.note)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  key: Key('admin.apps.reject.${application.id}'),
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: Key('admin.apps.approve.${application.id}'),
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
