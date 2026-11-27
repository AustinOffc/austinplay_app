import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/sse.dart';
import '../models/room.dart';
import '../services/audio_handler.dart';
import '../services/room_service.dart';
import 'core_providers.dart';
import 'music_providers.dart';

final roomServiceProvider =
    Provider<RoomService>((ref) => RoomService(ref.watch(apiClientProvider)));

enum RoomPhase { none, connecting, active }

class RoomState {
  const RoomState({
    this.phase = RoomPhase.none,
    this.busy = false,
    this.reconnecting = false,
    this.code = '',
    this.name = '',
    this.visibility = 'private',
    this.myPid = '',
    this.hostPid = '',
    this.isHost = false,
    this.hostOnline = true,
    this.members = const [],
    this.play,
  });

  final RoomPhase phase;
  final bool busy;
  final bool reconnecting;
  final String code;
  final String name;
  final String visibility;
  final String myPid;
  final String hostPid;
  final bool isHost;
  final bool hostOnline;
  final List<RoomMember> members;

  /// State pemutaran terakhir dari host.
  final RoomPlayState? play;

  bool get inRoom => phase != RoomPhase.none;

  RoomState copyWith({
    RoomPhase? phase,
    bool? busy,
    bool? reconnecting,
    String? name,
    String? visibility,
    String? hostPid,
    bool? isHost,
    bool? hostOnline,
    List<RoomMember>? members,
    RoomPlayState? play,
  }) =>
      RoomState(
        phase: phase ?? this.phase,
        busy: busy ?? this.busy,
        reconnecting: reconnecting ?? this.reconnecting,
        code: code,
        name: name ?? this.name,
        visibility: visibility ?? this.visibility,
        myPid: myPid,
        hostPid: hostPid ?? this.hostPid,
        isHost: isHost ?? this.isHost,
        hostOnline: hostOnline ?? this.hostOnline,
        members: members ?? this.members,
        play: play ?? this.play,
      );
}

/// Listen Together. Hanya HOST yang mengirim state; TAMU terkunci penuh dan mengikuti host
/// (posisi = state.pos + (sekarang − state.at), selisih jam dikoreksi lewat `serverNow`).
class RoomController extends Notifier<RoomState> {
  String _ticket = '';
  int _gen = 0;
  CancelToken? _cancel;
  int _offsetMs = 0;

  Timer? _beat;
  Timer? _pushDebounce;
  StreamSubscription<PlaybackState>? _psSub;
  String? _lastTrackId;
  bool _lastPlaying = false;
  Duration _lastPos = Duration.zero;
  DateTime _lastAt = DateTime.now();

  final StreamController<String> _notices = StreamController<String>.broadcast();

  /// Pesan untuk toast (dikeluarkan, room ditutup, dll).
  Stream<String> get notices => _notices.stream;

  RoomService get _svc => ref.read(roomServiceProvider);
  AuzifyAudioHandler get _h => ref.read(audioHandlerProvider);

  @override
  RoomState build() {
    ref.onDispose(() {
      _gen++;
      _cancel?.cancel();
      _beat?.cancel();
      _pushDebounce?.cancel();
      _psSub?.cancel();
    });
    return const RoomState();
  }

  // ---------- Aksi dari UI ----------

  /// Mengembalikan pesan error, atau null bila sukses.
  Future<String?> create({required String visibility, required String name}) async {
    if (state.inRoom) return 'Kamu sedang berada di sebuah room.';
    state = state.copyWith(busy: true);
    try {
      final user = ref.read(authProvider).user;
      final info = await _svc.create(
          visibility: visibility, name: name, hostName: user?.username ?? 'Host');
      _enter(info);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return ApiClient.messageOf(e);
    }
  }

  Future<String?> join(String code) async {
    final c = code.trim().toUpperCase();
    if (c.length < 4) return 'Kode room tidak valid.';
    if (state.inRoom) return 'Kamu sedang berada di sebuah room.';
    state = state.copyWith(busy: true);
    try {
      final info = await _svc.join(c);
      _enter(info);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return ApiClient.messageOf(e);
    }
  }

  /// Keluar dari room (bila host, room ikut ditutup oleh server).
  Future<void> leave() async {
    final code = state.code;
    final ticket = _ticket;
    _teardown();
    state = const RoomState();
    if (code.isEmpty) return;
    try {
      await _svc.leave(code, ticket);
    } catch (_) {}
  }

  Future<String?> end() async {
    final code = state.code;
    final ticket = _ticket;
    try {
      await _svc.end(code, ticket);
    } catch (e) {
      return ApiClient.messageOf(e);
    }
    _teardown();
    state = const RoomState();
    return null;
  }

  Future<String?> kick(String pid, {bool ban = false}) =>
      _act(() => _svc.kick(state.code, _ticket, pid, ban: ban));

  Future<String?> transfer(String pid) => _act(() => _svc.transfer(state.code, _ticket, pid));

  Future<String?> updateSettings({String? name, String? visibility}) =>
      _act(() => _svc.settings(state.code, _ticket, name: name, visibility: visibility));

  Future<List<BanEntry>> bans() async {
    try {
      return await _svc.bans(state.code, _ticket);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> unban(String id) => _act(() => _svc.unban(state.code, _ticket, id));

  /// Tamu: samakan lagi dengan posisi host ("Ikut lagi").
  void resync() {
    final p = state.play;
    if (p == null) {
      _notices.add('Host belum memutar lagu.');
      return;
    }
    unawaited(_follow(p));
  }

  Future<String?> _act(Future<void> Function() f) async {
    try {
      await f();
      return null;
    } catch (e) {
      return ApiClient.messageOf(e);
    }
  }

  // ---------- Masuk / keluar ----------

  void _enter(JoinInfo info) {
    _ticket = info.ticket;
    state = RoomState(
      phase: RoomPhase.connecting,
      code: info.code,
      name: info.room.name,
      visibility: info.room.visibility,
      myPid: info.pid,
      hostPid: info.host ? info.pid : '',
      isHost: info.host,
    );
    _applyRole(info.host);
    unawaited(_loop(++_gen));
  }

  void _teardown() {
    _gen++;
    _cancel?.cancel();
    _cancel = null;
    _beat?.cancel();
    _beat = null;
    _pushDebounce?.cancel();
    _psSub?.cancel();
    _psSub = null;
    final h = _h;
    final wasGuest = h.locked.value;
    h.locked.value = false;
    h.onLockedPlay = null;
    if (wasGuest) unawaited(h.pause());
    _ticket = '';
  }

  void _closed(String message) {
    _teardown();
    state = const RoomState();
    _notices.add(message);
  }

  // ---------- Koneksi SSE ----------

  Future<void> _loop(int gen) async {
    var fails = 0;
    while (gen == _gen) {
      final cancel = CancelToken();
      _cancel = cancel;
      try {
        await for (final ev in _svc.events(state.code, _ticket, cancel)) {
          if (gen != _gen) return;
          fails = 0;
          _onEvent(ev);
        }
      } catch (e) {
        if (gen != _gen) return;
        final status = e is DioException ? e.response?.statusCode : null;
        if (status == 403 || status == 404) {
          _closed('Room sudah ditutup.');
          return;
        }
      }
      if (gen != _gen) return;
      state = state.copyWith(reconnecting: true);
      fails++;
      if (fails > 40) {
        _closed('Koneksi ke room terputus.');
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  int _int(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  void _onEvent(SseEvent ev) {
    Map<String, dynamic> d;
    try {
      final j = jsonDecode(ev.data);
      d = j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
    } catch (_) {
      return;
    }
    switch (ev.event) {
      case 'hello':
        final serverNow = _int(d['serverNow']);
        if (serverNow > 0) _offsetMs = serverNow - DateTime.now().millisecondsSinceEpoch;
        final you = d['you'] is Map ? Map<String, dynamic>.from(d['you'] as Map) : <String, dynamic>{};
        final host = you['host'] == true;
        final play = RoomPlayState.tryParse(d['state']);
        state = state.copyWith(
          phase: RoomPhase.active,
          busy: false,
          reconnecting: false,
          name: (d['name'] ?? state.name).toString(),
          visibility: (d['visibility'] ?? state.visibility).toString(),
          hostPid: (d['hostPid'] ?? '').toString(),
          isHost: host,
          hostOnline: d['hostOnline'] != false,
          members: RoomMember.listFrom(d['members']),
          play: play,
        );
        _applyRole(host);
        if (host) {
          _hostPush('hello');
        } else if (play != null) {
          unawaited(_follow(play));
        }
        break;
      case 'members':
        final hostPid = (d['hostPid'] ?? '').toString();
        final nowHost = hostPid.isNotEmpty && hostPid == state.myPid;
        final changed = nowHost != state.isHost;
        state = state.copyWith(
            hostPid: hostPid, isHost: nowHost, members: RoomMember.listFrom(d['members']));
        if (changed) {
          _applyRole(nowHost);
          if (nowHost) {
            _hostPush('xfer');
          } else if (state.play != null) {
            unawaited(_follow(state.play!));
          }
        }
        break;
      case 'state':
        final np = RoomPlayState.tryParse(d);
        if (np == null) return;
        state = state.copyWith(play: np);
        if (!state.isHost) unawaited(_follow(np));
        break;
      case 'host':
        final online = d['online'] != false;
        state = state.copyWith(hostOnline: online);
        if (!state.isHost && state.play != null) unawaited(_follow(state.play!));
        break;
      case 'room':
        state = state.copyWith(
          name: (d['name'] ?? state.name).toString(),
          visibility: (d['visibility'] ?? state.visibility).toString(),
        );
        break;
      case 'kicked':
        final reason = (d['reason'] ?? '').toString();
        _closed(reason == 'ban'
            ? 'Kamu diblokir dari room ini.'
            : reason == 'replaced'
                ? 'Akunmu masuk ke room ini dari perangkat lain.'
                : 'Kamu dikeluarkan dari room.');
        break;
      case 'end':
        _closed('Room telah diakhiri host.');
        break;
    }
  }

  // ---------- Peran: host mengirim state, tamu terkunci ----------

  void _applyRole(bool host) {
    final h = _h;
    if (host) {
      h.locked.value = false;
      h.onLockedPlay = null;
      _startHostWatch();
    } else {
      _stopHostWatch();
      h.locked.value = true;
      h.onLockedPlay = resync;
    }
  }

  void _startHostWatch() {
    if (_psSub != null) return;
    final h = _h;
    _lastTrackId = h.currentTrack?.videoId;
    _lastPlaying = h.isPlaying;
    _lastPos = h.position;
    _lastAt = DateTime.now();
    _psSub = h.playbackState.listen(_onHostPlayback);
    _beat = Timer.periodic(const Duration(seconds: 5), (_) => _hostPush('beat'));
  }

  void _stopHostWatch() {
    _psSub?.cancel();
    _psSub = null;
    _beat?.cancel();
    _beat = null;
    _pushDebounce?.cancel();
  }

  void _onHostPlayback(PlaybackState ps) {
    final t = _h.currentTrack;
    if (t == null) return;
    final playing = ps.playing;
    final now = DateTime.now();
    String? ev;
    if (t.videoId != _lastTrackId) {
      ev = 'track';
    } else if (playing != _lastPlaying) {
      ev = playing ? 'play' : 'pause';
    } else {
      final elapsed = _lastPlaying
          ? Duration(milliseconds: (now.difference(_lastAt).inMilliseconds * ps.speed).round())
          : Duration.zero;
      final expected = _lastPos + elapsed;
      if ((ps.updatePosition - expected).abs() > const Duration(milliseconds: 1800)) ev = 'seek';
    }
    _lastTrackId = t.videoId;
    _lastPlaying = playing;
    _lastPos = ps.updatePosition;
    _lastAt = now;
    if (ev != null) _hostPush(ev, debounce: true);
  }

  void _hostPush(String ev, {bool debounce = false}) {
    if (!state.isHost || state.phase != RoomPhase.active) return;
    if (debounce) {
      _pushDebounce?.cancel();
      _pushDebounce = Timer(const Duration(milliseconds: 250), () => unawaited(_doPush(ev)));
    } else {
      unawaited(_doPush(ev));
    }
  }

  Future<void> _doPush(String ev) async {
    final h = _h;
    final t = h.currentTrack;
    if (t == null || !state.isHost || _ticket.isEmpty) return;
    final gen = _gen;
    try {
      await _svc.pushState(
          state.code, _ticket, t, h.isPlaying, h.position.inMilliseconds / 1000.0, ev);
    } catch (e) {
      if (gen != _gen) return;
      final msg = ApiClient.messageOf(e);
      if (e is ApiException && (e.status == 403 || e.status == 404)) {
        _closed(msg.isEmpty ? 'Room sudah ditutup.' : msg);
      }
    }
  }

  // ---------- Tamu: ikuti host ----------

  Future<void> _follow(RoomPlayState s) async {
    if (state.isHost) return;
    final playing = s.playing && state.hostOnline;
    final nowSrv = DateTime.now().millisecondsSinceEpoch + _offsetMs;
    var ms = (s.pos * 1000).round() + (s.playing ? (nowSrv - s.at) : 0);
    if (ms < 0) ms = 0;
    try {
      await _h.followRoom(s.track, Duration(milliseconds: ms), playing);
    } catch (_) {
      // gagal sementara; heartbeat host berikutnya (±5 dtk) mencoba lagi
    }
  }
}

final roomProvider = NotifierProvider<RoomController, RoomState>(RoomController.new);

/// Daftar room publik aktif (di-refresh berkala oleh layar Room).
final publicRoomsProvider = FutureProvider.autoDispose<List<RoomSummary>>(
    (ref) => ref.watch(roomServiceProvider).publicRooms());
