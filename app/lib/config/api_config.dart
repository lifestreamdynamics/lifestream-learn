/// Static configuration for the HTTP layer.
///
/// The base URL is baked in at compile time via `--dart-define=API_BASE_URL=...`.
/// Default `http://10.0.2.2:8090` is the Android emulator's alias for the host
/// machine (where `learn-api` listens on `:3011` but is fronted by the
/// `infra/` nginx at `:8090` in local dev).
///
/// This constant is the ONLY place a base URL default lives. Do not hard-code
/// `10.0.2.2` anywhere else.
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8090',
  );
}
