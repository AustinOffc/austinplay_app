import 'track.dart';

int _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _dbl(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Lagu pada ringkasan room (tanpa durasi).
class RoomTrackInfo {
  const RoomTrackInfo({required this.id, required this.title, required this.artist, required this.cover});
  final String id;
  final String title;
  final String artist;
  final String cover;

  factory RoomTrackInfo.fromJson(Map<String, dynamic> j) => RoomTrackInfo(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        artist: (j['artist'] ?? '').toString(),
        cover: coverFor((j['cover'] ?? '').toString(), (j['id'] ?? '').toString()),
      );
}

class RoomPreviewMember {
  const RoomPreviewMember({required this.name, this.avatar});
  final String name;
  final String? avatar;
}

/// Ringkasan room: GET /api/together/public, /:code/info, dan `room` pada create/join.
class RoomSummary {
  const RoomSummary({
    required this.code,
    required this.visibility,
    required this.name,
    required this.hostName,
    this.hostAvatar,
    required this.listeners,
    required this.hostOnline,
    required this.playing,
    this.track,
    this.preview = const [],
  });

  final String code;
  final String visibility;
  final String name;
  final String hostName;
  final String? hostAvatar;
  final int listeners;
  final bool hostOnline;
  final bool playing;
  final RoomTrackInfo? track;
  final List<RoomPreviewMember> preview;

  factory RoomSummary.fromJson(Map<String, dynamic> j) {
    final tr = j['track'];
    final pv = j['preview'];
    return RoomSummary(
      code: (j['code'] ?? '').toString(),
      visibility: (j['visibility'] ?? 'private').toString(),
      name: (j['name'] ?? '').toString(),
      hostName: (j['hostName'] ?? 'Host').toString(),
      hostAvatar: j['hostAvatar'] as String?,
      listeners: _int(j['listeners']),
      hostOnline: j['hostOnline'] != false,
      playing: j['playing'] == true,
      track: tr is Map ? RoomTrackInfo.fromJson(Map<String, dynamic>.from(tr)) : null,
      preview: pv is List
          ? pv
              .whereType<Map>()
              .map((e) => RoomPreviewMember(
                  name: (e['name'] ?? '').toString(), avatar: e['avatar'] as String?))
              .toList()
          : const [],
    );
  }
}

/// Anggota room (event `hello` / `members`).
class RoomMember {
  const RoomMember({
    required this.pid,
    required this.name,
    this.avatar,
    required this.host,
    required this.online,
    required this.guest,
    this.uid = 0,
  });

  /// ID akun (0 = tamu / tidak diketahui). Dipakai untuk lapor & blokir.
  final int uid;
  final String pid;
  final String name;
  final String? avatar;
  final bool host;
  final bool online;

  /// true = belum login (nama "Tamu xxxx").
  final bool guest;

  factory RoomMember.fromJson(Map<String, dynamic> j) => RoomMember(
        pid: (j['pid'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        avatar: j['avatar'] as String?,
        host: j['host'] == true,
        online: j['online'] != false,
        guest: j['guest'] == true,
        uid: _int(j['uid']),
      );

  static List<RoomMember> listFrom(Object? v) => v is List
      ? v.whereType<Map>().map((e) => RoomMember.fromJson(Map<String, dynamic>.from(e))).toList()
      : <RoomMember>[];
}

/// State pemutaran dari host: {track, playing, pos (detik), at (ms waktu server), ev}.
class RoomPlayState {
  const RoomPlayState({
    required this.track,
    required this.playing,
    required this.pos,
    required this.at,
    required this.ev,
  });

  final Track track;
  final bool playing;
  final double pos;
  final int at;
  final String ev;

  static RoomPlayState? tryParse(Object? v) {
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);
    final t = m['track'];
    if (t is! Map) return null;
    final track = Track.fromJson(Map<String, dynamic>.from(t));
    if (track.videoId.isEmpty) return null;
    return RoomPlayState(
      track: track,
      playing: m['playing'] == true,
      pos: _dbl(m['pos']),
      at: _int(m['at']),
      ev: (m['ev'] ?? '').toString(),
    );
  }
}

/// Balasan create / join.
class JoinInfo {
  const JoinInfo({
    required this.code,
    required this.pid,
    required this.ticket,
    required this.host,
    required this.room,
  });

  final String code;
  final String pid;
  final String ticket;
  final bool host;
  final RoomSummary room;

  factory JoinInfo.fromJson(Map<String, dynamic> j) {
    final code = (j['code'] ?? '').toString();
    final room = _map(j['room']);
    room['code'] = (room['code'] ?? code).toString();
    return JoinInfo(
      code: code,
      pid: (j['pid'] ?? '').toString(),
      ticket: (j['ticket'] ?? '').toString(),
      host: j['host'] == true,
      room: RoomSummary.fromJson(room),
    );
  }
}

class BanEntry {
  const BanEntry({required this.id, required this.name});
  final String id;
  final String name;
}
