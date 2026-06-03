/// Application environment, selected at build time via:
///   flutter run --dart-define=ENV=local|prod
///
/// `local` → talks to a backend running on the dev machine.
/// `prod`  → talks to the production API.
enum AppEnvironment {
  local,
  prod;

  static AppEnvironment fromName(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'local':
      case 'dev':
      default:
        return AppEnvironment.local;
    }
  }
}

/// Immutable, build-time configuration.
///
/// Reads `--dart-define` values once at startup. No secrets are stored here;
/// only base URLs and tunables that are safe to ship in the binary.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.tokenRefreshLeadTime,
    required this.unreadPollInterval,
    required this.billPayEnabledHint,
  });

  final AppEnvironment environment;

  /// API base, e.g. `https://api.lipa.example`.
  final String baseUrl;

  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Refresh the access token this long before it expires (spec: ~12 min on a
  /// 15-min TTL → 3 min lead).
  final Duration tokenRefreshLeadTime;

  /// Suggested cadence for polling the notifications unread badge.
  final Duration unreadPollInterval;

  /// Optimistic hint for whether bill-pay is on. The backend remains
  /// authoritative — a 404 on any bill-pay route flips this off at runtime.
  final bool billPayEnabledHint;

  static const String _envName =
      String.fromEnvironment('ENV', defaultValue: 'local');

  // Per-environment API hosts. `--dart-define=API_BASE_URL=...` overrides.
  // `localhost` works on a real device tethered over USB with
  //   `adb reverse tcp:8080 tcp:8080`, and on the emulator too (it forwards
  //   to the host loopback). For an emulator *without* `adb reverse`, override
  //   with `--dart-define=API_BASE_URL=http://10.0.2.2:8080`.
  static const String _localDefault = 'http://localhost:8080';
  static const String _prodDefault = 'https://api.lipa.km';
  static const String _baseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  factory AppConfig.fromEnvironment() {
    final env = AppEnvironment.fromName(_envName);
    final baseUrl = _resolveBaseUrl(env);
    return AppConfig(
      environment: env,
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      tokenRefreshLeadTime: const Duration(minutes: 3),
      unreadPollInterval: const Duration(seconds: 30),
      billPayEnabledHint: true,
    );
  }

  static String _resolveBaseUrl(AppEnvironment env) {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    switch (env) {
      case AppEnvironment.prod:
        return _prodDefault;
      case AppEnvironment.local:
        // localhost → host loopback via `adb reverse` (device) or emulator.
        return _localDefault;
    }
  }

  @override
  String toString() => 'AppConfig(env=$environment, baseUrl=$baseUrl)';
}
