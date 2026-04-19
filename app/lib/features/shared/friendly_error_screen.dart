import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Centrally styled error surface. Consumed by screens instead of raw
/// `Text(error.toString())` so:
/// - the user never sees a stack trace or raw API message,
/// - the "retry" and "go home" CTAs are consistent across the app.
///
/// In debug mode we pass the real error through `debugPrint` so
/// developers can still see what happened on the console; in release
/// (kReleaseMode) nothing is printed.
class FriendlyErrorScreen extends StatelessWidget {
  const FriendlyErrorScreen({
    required this.title,
    required this.message,
    this.debugError,
    this.onRetry,
    this.homePath = '/feed',
    super.key,
  });

  /// Short, user-facing title (e.g. "Couldn't load your applications").
  final String title;

  /// Sentence-length, user-facing body. Plain language — no "HTTP 500"
  /// or field names.
  final String message;

  /// Optional underlying error — never rendered, only logged in debug.
  final Object? debugError;

  /// Retry callback. When null, the Retry button is hidden.
  final VoidCallback? onRetry;

  /// Where the "Go home" CTA navigates. Defaults to `/feed` — override
  /// for flows where "home" means something else (e.g. admin).
  final String homePath;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && debugError != null) {
      debugPrint('FriendlyErrorScreen: $title — debugError: $debugError');
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (onRetry != null)
                      FilledButton.icon(
                        key: const Key('friendlyError.retry'),
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    OutlinedButton.icon(
                      key: const Key('friendlyError.goHome'),
                      onPressed: () => GoRouter.of(context).go(homePath),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Go home'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline (non-fullscreen) variant, for use inside an existing
/// `Scaffold` body where the app bar / bottom nav should stay. Same
/// contract — no stack traces, friendly language, Retry + Go home.
class FriendlyErrorBody extends StatelessWidget {
  const FriendlyErrorBody({
    required this.title,
    required this.message,
    this.debugError,
    this.onRetry,
    this.homePath = '/feed',
    super.key,
  });

  final String title;
  final String message;
  final Object? debugError;
  final VoidCallback? onRetry;
  final String homePath;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && debugError != null) {
      debugPrint('FriendlyErrorBody: $title — debugError: $debugError');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                if (onRetry != null)
                  FilledButton.icon(
                    key: const Key('friendlyError.retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                OutlinedButton.icon(
                  key: const Key('friendlyError.goHome'),
                  onPressed: () => GoRouter.of(context).go(homePath),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Go home'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
