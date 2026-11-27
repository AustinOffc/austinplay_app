import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/sse.dart';
import '../models/room.dart';
import '../models/track.dart';

/// Room / Listen Together (src/routes/together.routes.js). Login opsional.
class RoomService {
  RoomService(this._api);
  final ApiClient _api;

  static String _enc(String code) => Uri.encodeComponent(code.trim().toUpperCase());

  Future<JoinInfo> create({
    required String visibility,
    required String name,
    required String hostName,
  }) async {
    final r = await _api.post('/api/together/create',
        data: {'visibility': visibility, 'name': name, 'hostName': hostName}, soft401: true);
    return JoinInfo.fromJson(r);
  }

  Future<List<RoomSummary>> publicRooms() async {
    final r = await _api.get('/api/together/public', soft401: true);
    final list = r['rooms'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => RoomSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<JoinInfo> join(String code) async {
    final r = await _api.post('/api/together/${_enc(code)}/join', soft401: true);
    return JoinInfo.fromJson(r);
  }

  /// Event: hello, members, state, host, room, kicked, end.
  Stream<SseEvent> events(String code, String ticket, CancelToken cancel) => openSse(
        _api.dio,
        '/api/together/${_enc(code)}/events',
        query: {'t': ticket},
        cancel: cancel,
        soft401: true,
      );

  Future<void> pushState(
      String code, String ticket, Track track, bool playing, double pos, String ev) async {
    await _api.post('/api/together/${_enc(code)}/state', soft401: true, data: {
      'ticket': ticket,
      'state': {
        'track': {
          'id': track.videoId,
          'videoId': track.videoId,
          'title': track.title,
          'artist': track.artist,
          'artistId': track.artistId,
          'cover': track.cover,
        },
        'playing': playing,
        'pos': pos,
        'ev': ev,
      },
    });
  }

  Future<void> kick(String code, String ticket, String pid, {bool ban = false}) async {
    await _api.post('/api/together/${_enc(code)}/kick',
        data: {'ticket': ticket, 'pid': pid, 'ban': ban}, soft401: true);
  }

  Future<void> transfer(String code, String ticket, String pid) async {
    await _api.post('/api/together/${_enc(code)}/transfer',
        data: {'ticket': ticket, 'pid': pid}, soft401: true);
  }

  Future<void> settings(String code, String ticket, {String? name, String? visibility}) async {
    await _api.post('/api/together/${_enc(code)}/settings', soft401: true, data: {
      'ticket': ticket,
      if (name != null) 'name': name,
      if (visibility != null) 'visibility': visibility,
    });
  }

  Future<List<BanEntry>> bans(String code, String ticket) async {
    final r = await _api.post('/api/together/${_enc(code)}/bans',
        data: {'ticket': ticket}, soft401: true);
    final list = r['bans'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => BanEntry(id: (e['id'] ?? '').toString(), name: (e['name'] ?? '').toString()))
        .toList();
  }

  Future<void> unban(String code, String ticket, String id) async {
    await _api.post('/api/together/${_enc(code)}/unban',
        data: {'ticket': ticket, 'id': id}, soft401: true);
  }

  Future<void> leave(String code, String ticket) async {
    await _api.post('/api/together/${_enc(code)}/leave', data: {'ticket': ticket}, soft401: true);
  }

  Future<void> end(String code, String ticket) async {
    await _api.post('/api/together/${_enc(code)}/end', data: {'ticket': ticket}, soft401: true);
  }
}
