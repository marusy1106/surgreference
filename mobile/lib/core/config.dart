/// Сборочные параметры: `flutter run --dart-define=API_BASE_URL=https://api.example.ru/api/v1/`.
abstract final class AppConfig {
  /// Эмулятор Android видит компьютер разработчика по адресу 10.0.2.2, симулятор iOS — по localhost.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000/api/v1/');
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
}
