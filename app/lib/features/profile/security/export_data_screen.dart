import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/repositories/me_repository.dart';

/// Slice P8 — Export my data.
///
/// GDPR "right of access" surface. Explains what's included and what
/// isn't, fetches `GET /api/me/export`, writes the JSON to the app's
/// documents directory, and opens the OS share sheet so the user can
/// send it to Gmail / Drive / Files / wherever.
///
/// Rate-limit behaviour:
///   - Server enforces 1 export per 24h per user.
///   - On 429 the repo throws [ExportRateLimitException]; we convert
///     the `retry-after` seconds into a "Try again in X hours" message
///     the user can act on.
///
/// The screen does NOT store the export anywhere permanent — the file
/// lands in `ApplicationDocumentsDirectory` with a date-suffixed name.
/// Re-running on the same day will overwrite the previous file with
/// the same date; that's fine — the server rate-limits to one per day
/// anyway, so the on-disk copy can only lag one version behind the
/// most recent export.
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({
    required this.meRepo,
    super.key,
    // Injected for testability — defaults target the real platform.
    this.docsDirResolver,
    this.shareFn,
    this.fileWriter,
  });

  final MeRepository meRepo;

  /// Override the documents-dir resolver in tests. Falls back to
  /// `getApplicationDocumentsDirectory()` at call time.
  final Future<Directory> Function()? docsDirResolver;

  /// Override the share-sheet invocation in tests. Signature matches
  /// `Share.shareXFiles` but narrowed to the single-file case we use.
  final Future<ShareResult> Function(List<XFile> files, {String? subject})?
      shareFn;

  /// Override the file write in tests. The default calls
  /// `File(path).writeAsString(contents)`, which is real dart:io and
  /// doesn't complete under a testWidgets fake-async zone; tests can
  /// inject a no-op / in-memory writer to bypass real I/O.
  final Future<void> Function(String path, String contents)? fileWriter;

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

enum _Status {
  idle,
  loading,
  success,
  error,
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  _Status _status = _Status.idle;
  String? _errorMessage;
  String? _savedPath;

  Future<void> _export() async {
    if (_status == _Status.loading) return;
    setState(() {
      _status = _Status.loading;
      _errorMessage = null;
      _savedPath = null;
    });

    try {
      final payload = await widget.meRepo.exportMyData();

      // Pretty-print the JSON so the file is human-readable if the user
      // opens it in a text viewer. `JsonEncoder.withIndent('  ')` adds
      // two-space indentation without re-ordering keys — matches what
      // most code formatters default to for JSON.
      final bodyString = const JsonEncoder.withIndent('  ').convert(payload);

      final docsDir = widget.docsDirResolver != null
          ? await widget.docsDirResolver!()
          : await getApplicationDocumentsDirectory();

      // Date-suffixed filename — users can keep a loose audit trail if
      // they export repeatedly over time. The server-side filename
      // (in the Content-Disposition header) also embeds the user id,
      // but our side keeps just the date for brevity on the local disk.
      final today = DateTime.now().toUtc();
      final dateStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final filename = 'lifestream-learn-export-$dateStr.json';
      final filePath = '${docsDir.path}/$filename';
      if (widget.fileWriter != null) {
        await widget.fileWriter!(filePath, bodyString);
      } else {
        await File(filePath).writeAsString(bodyString);
      }

      // Kick off the share sheet. The user can cancel the share but
      // the file is still saved — report success either way so they
      // can re-share from the Files app later. `share_plus` handles
      // Android's FileProvider wiring internally via its manifest
      // contributions (declared in the plugin's AndroidManifest).
      if (widget.shareFn != null) {
        await widget.shareFn!(
          [XFile(filePath, mimeType: 'application/json', name: filename)],
          subject: 'Your Lifestream Learn data',
        );
      } else {
        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/json', name: filename)],
          subject: 'Your Lifestream Learn data',
        );
      }

      if (!mounted) return;
      setState(() {
        _status = _Status.success;
        _savedPath = filePath;
      });
    } on ExportRateLimitException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorMessage = _friendlyRateLimitMessage(e.retryAfterSeconds);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorMessage = e.statusCode == 401
            ? 'You need to sign in again to export your data.'
            : e.statusCode == 403
                ? 'Export is not available because your account is pending deletion.'
                : 'Could not export your data. Please try again later.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _errorMessage = 'Could not export your data. Please try again later.';
      });
    }
  }

  /// Turn a `Retry-After` seconds count into a human phrase. Server
  /// serves a 24h ceiling so the typical value is roughly a day; we
  /// render "X hours" when the remaining window is at least an hour
  /// and "X minutes" otherwise. Keeps the UI readable without pulling
  /// in `intl` for full pluralisation rules.
  String _friendlyRateLimitMessage(int? retryAfterSeconds) {
    if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
      return 'You can export once per day. Try again later.';
    }
    if (retryAfterSeconds >= 3600) {
      final hours = (retryAfterSeconds / 3600).ceil();
      return 'You can export once per day. Try again in $hours '
          '${hours == 1 ? 'hour' : 'hours'}.';
    }
    final minutes = (retryAfterSeconds / 60).ceil();
    return 'You can export once per day. Try again in $minutes '
        '${minutes == 1 ? 'minute' : 'minutes'}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Export my data')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.download_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What\'s in the export',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A JSON file containing:',
                      ),
                      const SizedBox(height: 4),
                      const _BulletLine(
                          'Your profile: email, display name, role, preferences'),
                      const _BulletLine(
                          'Your enrollments, quiz attempts, and achievements'),
                      const _BulletLine(
                          'Your recent activity events (up to 10,000)'),
                      const _BulletLine(
                          'Your active and recent sessions (IP hashes are truncated)'),
                      const SizedBox(height: 12),
                      Text(
                        'What\'s NOT included',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      const _BulletLine(
                          'Your password hash and any two-factor credentials'),
                      const _BulletLine(
                          'Courses you authored (separately copyrightable)'),
                      const _BulletLine(
                          'Other users\' data that references yours'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can export your data once every 24 hours.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('exportData.export'),
                onPressed:
                    _status == _Status.loading ? null : _export,
                icon: _status == _Status.loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_outlined),
                label: Text(
                  _status == _Status.loading
                      ? 'Preparing your export...'
                      : 'Export and share',
                ),
              ),
              const SizedBox(height: 16),
              if (_status == _Status.success && _savedPath != null)
                Card(
                  key: const Key('exportData.successCard'),
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Export ready',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saved to: $_savedPath',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_status == _Status.error && _errorMessage != null)
                Card(
                  key: const Key('exportData.errorCard'),
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
