/// Konfigurasi aplikasi. Ganti base URL lewat --dart-define=API_BASE=https://domain-kamu
class AppConfig {
  static const String apiBase =
      String.fromEnvironment('API_BASE', defaultValue: 'https://auzify.example.com');
  static const String appVersion = '1.0.0';
  static const String webVersion = '3.9.3';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Ubah path relatif (mis. avatar) jadi URL absolut.
  static String? absUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }
}
