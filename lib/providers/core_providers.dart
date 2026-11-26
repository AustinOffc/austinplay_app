import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStoreProvider)));

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(apiClientProvider)));

class AuthState {
  const AuthState({this.ready = false, this.user, this.busy = false});
  final bool ready;
  final AppUser? user;
  final bool busy;
  bool get loggedIn => user != null;

  AuthState copyWith({bool? ready, AppUser? user, bool? busy, bool clearUser = false}) => AuthState(
        ready: ready ?? this.ready,
        user: clearUser ? null : (user ?? this.user),
        busy: busy ?? this.busy,
      );
}

class AuthController extends Notifier<AuthState> {
  static const _userKey = 'cached_user';

  @override
  AuthState build() {
    ref.read(apiClientProvider).onUnauthorized = _expired;
    return const AuthState();
  }

  Future<AppUser?> _loadCachedUser() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_userKey);
      if (s == null) return null;
      final m = jsonDecode(s);
      return m is Map<String, dynamic> ? AppUser.fromJson(m) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUser(AppUser? u) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (u == null) {
        await p.remove(_userKey);
      } else {
        await p.setString(_userKey, jsonEncode(u.toJson()));
      }
    } catch (_) {}
  }

  /// Dipanggil sekali saat splash.
  Future<void> init() async {
    final tokens = ref.read(tokenStoreProvider);
    await tokens.load();
    if (!tokens.hasToken) {
      state = const AuthState(ready: true);
      return;
    }
    final cached = await _loadCachedUser();
    state = AuthState(ready: true, user: cached);
    try {
      final u = await ref.read(authServiceProvider).me().timeout(const Duration(seconds: 6));
      await _saveUser(u);
      state = AuthState(ready: true, user: u);
    } catch (_) {
      // Offline / lambat: tetap pakai data tersimpan. 401 ditangani interceptor.
    }
  }

  Future<void> _expired() async {
    await ref.read(tokenStoreProvider).clear();
    await _saveUser(null);
    state = const AuthState(ready: true);
  }

  /// Mengembalikan pesan error, atau null bila sukses.
  Future<String?> signIn(String username, String password, {required bool register}) async {
    state = state.copyWith(busy: true);
    try {
      final svc = ref.read(authServiceProvider);
      final res = register
          ? await svc.register(username.trim(), password)
          : await svc.login(username.trim(), password);
      await ref.read(tokenStoreProvider).save(res.token);
      await _saveUser(res.user);
      state = AuthState(ready: true, user: res.user);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return ApiClient.messageOf(e);
    }
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).logout();
    await _expired();
  }

  /// Mengembalikan pesan error, atau null bila sukses.
  Future<String?> signOutAll() async {
    try {
      await ref.read(authServiceProvider).logoutAll();
      await _expired();
      return null;
    } catch (e) {
      return ApiClient.messageOf(e);
    }
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
