/// Where the app talks to. Overridable at build time for a staging server:
///   flutter run --dart-define=API_BASE=https://staging.example/api/v1
class AppConfig {
  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://easybuy.com.bd/api/v1',
  );

  /// The website, for links the app hands to the browser (terms, pages).
  static const siteBase = String.fromEnvironment(
    'SITE_BASE',
    defaultValue: 'https://easybuy.com.bd',
  );

  /// Sent with the push registration, so support can tell old builds apart.
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
}
