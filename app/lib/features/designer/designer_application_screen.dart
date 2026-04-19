import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/http/error_envelope.dart';
import '../../data/models/designer_application.dart';
import '../../data/repositories/designer_application_repository.dart';
import '../shared/friendly_error_screen.dart';

/// Learner-facing designer-application screen. Four states keyed off the
/// server's `DesignerApplication` row:
/// - **null** (never applied): form with an optional note.
/// - **PENDING**: "under review" card with submission date.
/// - **APPROVED**: success card + CTA to Designer home.
/// - **REJECTED**: reviewer note + resubmit form.
class DesignerApplicationScreen extends StatefulWidget {
  const DesignerApplicationScreen({required this.repo, super.key});

  final DesignerApplicationRepository repo;

  @override
  State<DesignerApplicationScreen> createState() =>
      _DesignerApplicationScreenState();
}

class _DesignerApplicationScreenState extends State<DesignerApplicationScreen> {
  /// Loading the existing application on mount.
  bool _loading = true;

  /// The caller's current application — null when they've never applied.
  DesignerApplication? _application;

  /// Error state from the initial load.
  Object? _loadError;

  /// In-flight submission guard.
  bool _submitting = false;

  /// Error surfaced inline on the submit form.
  String? _submitError;

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final app = await widget.repo.getMy();
      if (!mounted) return;
      setState(() {
        _application = app;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final note = _noteController.text.trim();
    if (note.length > 2000) {
      setState(() {
        _submitError = 'Note must be 2000 characters or fewer.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final app = await widget.repo.submit(note: note.isEmpty ? null : note);
      if (!mounted) return;
      setState(() {
        _application = app;
        _submitting = false;
        _noteController.clear();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = 'Could not submit — please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become a designer')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      // Skeletonizer wraps an opaque "fake card" so the screen doesn't
      // flash a spinner on fast connections.
      return Skeletonizer(
        enabled: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              _SkeletonCard(),
              SizedBox(height: 16),
              _SkeletonCard(),
            ],
          ),
        ),
      );
    }
    if (_loadError != null) {
      return FriendlyErrorBody(
        title: "Couldn't load your application",
        message:
            "We couldn't reach the server to check your application "
            'status. You can retry in a moment.',
        debugError: _loadError,
        onRetry: _load,
      );
    }
    final app = _application;
    if (app == null) {
      return _buildForm(context, heading: null);
    }
    switch (app.status) {
      case AppStatus.pending:
        return _buildPending(context, app);
      case AppStatus.approved:
        return _buildApproved(context, app);
      case AppStatus.rejected:
        return _buildRejected(context, app);
    }
  }

  Widget _buildForm(BuildContext context, {Widget? heading}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading != null) heading,
          Text(
            "Tell us a little about what you'd like to teach. The note "
            'is optional — an empty application is fine.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('designerApp.note'),
            controller: _noteController,
            enabled: !_submitting,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              _submitError!,
              key: const Key('designerApp.submitError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('designerApp.submit'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit application'),
          ),
        ],
      ),
    );
  }

  Widget _buildPending(BuildContext context, DesignerApplication app) {
    final submitted = _formatDate(app.submittedAt);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        key: const Key('designerApp.pending'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 48),
              const SizedBox(height: 12),
              Text(
                'Your application is under review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Submitted on $submitted. An admin will review it soon — '
                "we'll update this screen automatically when they do.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApproved(BuildContext context, DesignerApplication app) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        key: const Key('designerApp.approved'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, size: 48),
              const SizedBox(height: 12),
              Text(
                "You're now a Course Designer!",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Your application was approved. Head to the Designer home '
                'to start creating courses.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('designerApp.goDesigner'),
                onPressed: () => GoRouter.of(context).go('/designer'),
                child: const Text('Go to Designer home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejected(BuildContext context, DesignerApplication app) {
    final reviewerNote = app.reviewerNote;
    return _buildForm(
      context,
      heading: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          key: const Key('designerApp.rejected'),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your previous application was not approved.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'You may apply again with updated information below.',
                ),
                if (reviewerNote != null && reviewerNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reviewer note: $reviewerNote',
                    key: const Key('designerApp.reviewerNote'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Loading title placeholder for skeleton layout'),
            SizedBox(height: 8),
            Text(
              'Loading longer body text placeholder that the skeletonizer '
              'will shimmer in place of the real message.',
            ),
          ],
        ),
      ),
    );
  }
}
