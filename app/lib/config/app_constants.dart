/// Cross-cutting numeric constants that currently appear as magic numbers in
/// more than one place, plus a few one-offs pulled in alongside them so the
/// pagination/upload knobs live together.
///
/// Centralising these here lets QA + backend tune them without grepping the
/// feature folders, and pairs with [CrashReportingConfig] / [ApiConfig] as
/// the three config files under `lib/config/`.
class AppConstants {
  const AppConstants._();

  /// Feed and courses paginated list size. Used by [FeedBloc] and
  /// [CoursesBloc]. Matches the `limit` default in `api/src/routes/feed.ts`.
  static const int feedPageSize = 20;

  /// Designer / admin list-page size. Higher than the learner feed because
  /// the designer home + admin analytics screens show a single page and
  /// rely on the user scrolling rather than infinite-loading.
  static const int designerListLimit = 50;

  /// Max chunk size for resumable TUS uploads. 5 MiB balances a reasonable
  /// retry granularity with not re-sending too much data on a mobile
  /// network hiccup. Matches the tusd server's configured chunk limit in
  /// `infra/docker-compose.yml`.
  static const int tusMaxChunkBytes = 5 * 1024 * 1024;
}
