import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/sse.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'core_providers.dart';
import 'nav_providers.dart';

final chatServiceProvider =
    Provider<ChatService>((ref) => ChatService(ref.watch(apiClientProvider)));

class ChatState {
  const ChatState({
    this.messages = const [],
    this.hasMore = false,
    this.online = 0,
    this.meId = 0,
    this.admin = false,
    this.loading = false,
    this.connected = false,
    this.error = '',
  });

  /// Urut naik berdasarkan id (terlama → terbaru).
  final List<ChatMessage> messages;
  final bool hasMore;
  final int online;
  final int meId;
  final bool admin;
  final bool loading;
  final bool connected;
  final String error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    int? online,
    int? meId,
    bool? admin,
    bool? loading,
    bool? connected,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        hasMore: hasMore ?? this.hasMore,
        online: online ?? this.online,
        meId: meId ?? this.meId,
        admin: admin ?? this.admin,
        loading: loading ?? this.loading,
        connected: connected ?? this.connected,
        error: error ?? this.error,
      );
}

/// Chat Global: aktif hanya saat tab Chat terlihat dan sudah login.
/// Real-time lewat SSE; saat putus, sebelum tiap percobaan sambung ulang diambil pesan
/// yang terlewat lewat `?after=<idTerakhir>` (cadangan polling).
class ChatController extends Notifier<ChatState> {
  static const int _chatTab = 4;
  static const int _keep = 600;

  int _gen = 0;
  bool _active = false;
  bool _loadingOlder = false;
  CancelToken? _cancel;

  ChatService get _svc => ref.read(chatServiceProvider);

  @override
  ChatState build() {
    ref.listen<int>(tabIndexProvider, (_, __) => refreshActive());
    ref.listen<bool>(authProvider.select((s) => s.loggedIn), (_, __) => refreshActive());
    ref.onDispose(_halt);
    return const ChatState();
  }

  /// Dipanggil ChatScreen saat dibuat, dan otomatis saat tab / login berubah.
  void refreshActive() {
    final want = ref.read(tabIndexProvider) == _chatTab && ref.read(authProvider).loggedIn;
    if (want && !_active) {
      _active = true;
      _start();
    } else if (!want && _active) {
      _active = false;
      _halt();
      if (!ref.read(authProvider).loggedIn) {
        state = const ChatState();
      } else if (state.connected) {
        state = state.copyWith(connected: false);
      }
    }
  }

  /// App dilanjutkan dari latar belakang: koneksi lama mungkin sudah mati.
  void reconnect() {
    if (!_active) return;
    _halt();
    _start();
  }

  void _halt() {
    _gen++;
    _cancel?.cancel();
    _cancel = null;
  }

  void _start() {
    final gen = ++_gen;
    state = state.copyWith(loading: state.messages.isEmpty, error: '');
    unawaited(_run(gen));
  }

  int? _statusOf(Object e) {
    if (e is ApiException) return e.status;
    if (e is DioException) return e.response?.statusCode;
    return null;
  }

  Future<void> _run(int gen) async {
    while (gen == _gen) {
      try {
        await _catchUp();
        if (gen != _gen) return;
        final cancel = CancelToken();
        _cancel = cancel;
        await for (final ev in _svc.events(cancel)) {
          if (gen != _gen) return;
          _onEvent(ev);
        }
      } catch (e) {
        if (gen != _gen) return;
        // 401: sesi habis — AuthController sudah mengeluarkan user, berhenti.
        if (_statusOf(e) == 401) return;
        state = state.copyWith(loading: false, error: ApiClient.messageOf(e));
      }
      if (gen != _gen) return;
      state = state.copyWith(connected: false);
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _catchUp() async {
    if (state.messages.isEmpty) {
      final p = await _svc.messages(limit: 40);
      _merge(p.messages);
      state = state.copyWith(
          hasMore: p.hasMore, online: p.online, meId: p.meId, admin: p.admin, loading: false, error: '');
    } else {
      final p = await _svc.messages(after: state.messages.last.id);
      _merge(p.messages);
      state = state.copyWith(online: p.online, meId: p.meId, admin: p.admin, loading: false, error: '');
    }
  }

  void _onEvent(SseEvent ev) {
    switch (ev.event) {
      case 'hello':
        final d = _json(ev.data);
        final me = d['me'] is Map ? Map<String, dynamic>.from(d['me'] as Map) : <String, dynamic>{};
        state = state.copyWith(
          connected: true,
          error: '',
          online: d['online'] is num ? (d['online'] as num).toInt() : state.online,
          admin: me['admin'] == true,
        );
        break;
      case 'msg':
        final d = _json(ev.data);
        if (d.isNotEmpty) _merge([ChatMessage.fromJson(d)]);
        break;
      case 'del':
        final d = _json(ev.data);
        final id = d['id'];
        if (id is num) _drop(id.toInt());
        break;
      case 'presence':
        final d = _json(ev.data);
        if (d['online'] is num) state = state.copyWith(online: (d['online'] as num).toInt());
        break;
    }
  }

  Map<String, dynamic> _json(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _merge(List<ChatMessage> add) {
    if (add.isEmpty) return;
    final byId = <int, ChatMessage>{for (final m in state.messages) m.id: m};
    for (final m in add) {
      if (m.id > 0) byId[m.id] = m;
    }
    var list = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    if (list.length > _keep) list = list.sublist(list.length - _keep);
    state = state.copyWith(messages: list);
  }

  void _drop(int id) {
    if (!state.messages.any((m) => m.id == id)) return;
    state = state.copyWith(messages: state.messages.where((m) => m.id != id).toList());
  }

  /// Muat pesan yang lebih lama (dipanggil saat scroll ke atas).
  Future<void> loadOlder() async {
    if (_loadingOlder || !state.hasMore || state.messages.isEmpty) return;
    _loadingOlder = true;
    try {
      final p = await _svc.messages(before: state.messages.first.id);
      _merge(p.messages);
      state = state.copyWith(hasMore: p.hasMore);
    } catch (_) {
      // dicoba lagi saat user menggulir lagi
    } finally {
      _loadingOlder = false;
    }
  }

  /// Mengembalikan pesan error, atau null bila sukses.
  Future<String?> send(String text) async {
    try {
      final m = await _svc.send(text);
      _merge([m]);
      return null;
    } catch (e) {
      return ApiClient.messageOf(e);
    }
  }

  Future<String?> remove(int id) async {
    try {
      await _svc.delete(id);
      _drop(id);
      return null;
    } catch (e) {
      return ApiClient.messageOf(e);
    }
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
