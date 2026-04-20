/// Compile-time configuration for `lifestream_doctor` crash reporting.
///
/// Values are resolved at build time via `--dart-define` flags. When no
/// API key is supplied, [hasCrashReportingConfig] returns `false` and the
/// reporter is constructed in `enabled: false` mode so every
/// `captureException` / `captureMessage` call is a silent no-op. This
/// lets us ship the integration before the `learn-crashes` vault is
/// provisioned, with zero risk of upload attempts against an invalid
/// endpoint.
///
/// **Key rotation.** When the `learn-crashes` vault is provisioned:
///   1. Ask the vault admin to issue an API key scoped `read,write`
///      and restricted to that vault (least privilege).
///   2. Store the resulting `lsv_k_*` key in the CI secrets store as
///      `LEARN_CRASH_API_KEY` and the vault base URL as
///      `LEARN_CRASH_API_URL`.
///   3. Pass them at build time: `flutter build apk \
///        --dart-define=LEARN_CRASH_API_URL=https://vault.example.com \
///        --dart-define=LEARN_CRASH_API_KEY=lsv_k_...`.
/// No code change in this repo is required to ship the key.
class CrashReportingConfig {
  const CrashReportingConfig._();

  /// Base URL for the Lifestream Vault crash reporting API. Empty by
  /// default — a real URL must be supplied via `--dart-define` for the
  /// SDK to be enabled.
  static const String crashApiUrl = String.fromEnvironment(
    'LEARN_CRASH_API_URL',
  );

  /// Vault identifier for crash report storage. Defaults to the
  /// ecosystem convention `learn-crashes`; override with
  /// `--dart-define=LEARN_CRASH_VAULT_ID=...` if the admin provisions
  /// the vault under a different id.
  static const String crashVaultId = String.fromEnvironment(
    'LEARN_CRASH_VAULT_ID',
    defaultValue: 'learn-crashes',
  );

  /// API key for authenticating with the Vault crash API. Placeholder
  /// default: empty string. `hasCrashReportingConfig` returns false
  /// until a real `lsv_k_*` key is supplied via `--dart-define`.
  static const String crashApiKey = String.fromEnvironment(
    'LEARN_CRASH_API_KEY',
  );

  /// True when both a URL and a key are present. The crash reporter
  /// constructs its `LifestreamDoctor` with `enabled:` bound to this
  /// value, so missing config means capture calls silently no-op.
  static bool get hasCrashReportingConfig =>
      crashApiUrl.isNotEmpty && crashApiKey.isNotEmpty;
}
