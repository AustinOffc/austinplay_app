import '../core/api_client.dart';
import '../models/user.dart';

class AuthResult {
  const AuthResult(this.token, this.user);
  final String token;
  final AppUser user;
}

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  Future<AuthResult> login(String username, String password) =>
      _auth('/api/auth/login', username, password);

  Future<AuthResult> register(String username, String password) =>
      _auth('/api/auth/register', username, password);

  Future<AuthResult> _auth(String path, String username, String password) async {
    final r = await _api.post(path,
        data: {'username': username, 'password': password}, soft401: true);
    final token = r['token'];
    final user = r['user'];
    if (token is! String || user is! Map<String, dynamic>) {
      throw ApiException('Balasan server tidak dikenali.');
    }
    return AuthResult(token, AppUser.fromJson(user));
  }

  Future<AppUser> me() async {
    final r = await _api.get('/api/auth/me');
    final user = r['user'];
    if (user is! Map<String, dynamic>) throw ApiException('Balasan server tidak dikenali.');
    return AppUser.fromJson(user);
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout', soft401: true);
    } catch (_) {}
  }

  Future<void> logoutAll() async {
    await _api.post('/api/auth/logout-all');
  }

  /// Mengembalikan token baru (device lain otomatis keluar).
  Future<String> changePassword(String oldPassword, String newPassword) async {
    final r = await _api.post('/api/auth/change-password',
        data: {'oldPassword': oldPassword, 'newPassword': newPassword}, soft401: true);
    final token = r['token'];
    if (token is! String) throw ApiException('Balasan server tidak dikenali.');
    return token;
  }

  /// Unggah foto profil (data URL jpeg/png/webp ≤150 KB). Mengembalikan path avatar baru.
  Future<String?> setAvatar(String dataUrl) async {
    final r = await _api.put('/api/auth/avatar', data: {'image': dataUrl});
    return r['avatar'] as String?;
  }

  /// Hapus akun permanen (butuh password). Server menghapus data sinkron, pesan chat, dan daftar blokir.
  Future<void> deleteAccount(String password) async {
    await _api.delete('/api/auth/account', data: {'password': password}, soft401: true);
  }

  Future<void> removeAvatar() async {
    await _api.delete('/api/auth/avatar');
  }
}
