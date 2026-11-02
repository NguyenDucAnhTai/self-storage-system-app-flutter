class AppConfig {
  AppConfig._();
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://self-storage-system-be.onrender.com',
  );
}
