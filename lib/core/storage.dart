import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token login disimpan aman di perangkat; salinan memori dipakai interceptor Dio.
class TokenStore {
  static const _key = 'auth_token';
  final FlutterSecureStorage _s = const FlutterSecureStorage();
  String? _token;

  String? get cached => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> load() async {
    try {
      _token = await _s.read(key: _key);
    } catch (_) {
      _token = null;
    }
  }

  Future<void> save(String token) async {
    _token = token;
    try {
      await _s.write(key: _key, value: token);
    } catch (_) {}
  }

  Future<void> clear() async {
    _token = null;
    try {
      await _s.delete(key: _key);
    } catch (_) {}
  }
}
