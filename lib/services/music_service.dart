import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../models/browse.dart';
import '../models/lyrics.dart';
import '../models/sb_segment.dart';
import '../models/track.dart';
import 'lyrics_cache.dart';

/// Gagal memutar. [retryable]=false → jangan diulang, lewati lagu.
class PlayFailure implements Exception {
  const PlayFailure(this.message, {this.retryable = true});
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

/// Hasil /api/ytplay.
class ResolvedAudio {
  ResolvedAudio(this.audio, this.needProxy) : at = DateTime.now();

  /// URL langsung (https://...) atau "local:<id>.<ext>" (tanpa fragmen #via-proxy).
  final String audio;

  /// true bila WAJIB lewat /api/proxy-audio (local: atau #via-proxy).
  final bool needProxy;
  final DateTime at;

  bool get fresh => DateTime.now().difference(at) < const Duration(minutes: 90);
  String get direct => audio;
  String get proxy =>
      AppConfig.absUrl('/api/proxy-audio?url=${Uri.encodeComponent(audio)}')!;
}

/// Lapisan sumber audio: ganti implementasi ini bila sumber audio diganti (lihat PROMPT bagian 10).
abstract class StreamSource {
  Future<ResolvedAudio> resolve(String videoId, {bool refresh = false, bool prefetch = false});
}

class MusicService implements StreamSource {
  MusicService(this._api);
  final ApiClient _api;

  /// Cache lirik untuk lagu yang sudah diunduh (diisi di main.dart).
  LyricsCache? lyricsCache;

  static List<Map<String, dynamic>> _maps(Object? v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  /// type: all | songs | playlists | artists | videos
  Future<SearchResult> search(String query, {String type = 'all'}) async {
    final r = await _api.get('/api/search', query: {'query': query, 'type': type});
    final res = r['result'];
    final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    return SearchResult(
      songs: _maps(m['songs'])
          .map(Track.fromSearch)
          .where((t) => t.videoId.isNotEmpty)
          .toList(),
      albums: _maps(m['albums']).map((e) => BrowseItem.fromJson(e, BrowseKind.album)).toList(),
      playlists:
          _maps(m['playlists']).map((e) => BrowseItem.fromJson(e, BrowseKind.playlist)).toList(),
      artists: _maps(m['artists']).map((e) => BrowseItem.fromJson(e, BrowseKind.artist)).toList(),
    );
  }

  /// /api/suggest membalas ARRAY (bukan {result}).
  Future<List<String>> suggest(String q) async {
    final d = await _api.getRaw('/api/suggest', query: {'q': q});
    if (d is! List) return const [];
    return d
        .map((e) => e is String ? e : (e is Map ? (e['text'] ?? e['query'] ?? '').toString() : ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Future<ResolvedAudio> resolve(String videoId,
      {bool refresh = false, bool prefetch = false}) async {
    final body = <String, dynamic>{'query': 'https://youtube.com/watch?v=$videoId'};
    if (refresh) body['refresh'] = true;
    if (prefetch) {
      body['prefetch'] = true;
      body['wantLocal'] = true;
    }
    final Response<dynamic> res;
    try {
      res = await _api.rawPost('/api/ytplay', data: body, timeout: const Duration(seconds: 55));
    } on ApiException catch (e) {
      throw PlayFailure(e.message);
    }
    final d = res.data;
    final map = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    if (res.statusCode != 200 || map['status'] == false) {
      final code = (map['code'] ?? '').toString();
      final retryable =
          map['retryable'] != false && code != 'VIDEO_UNAVAILABLE' && code != 'BAD_ID';
      final msg = (map['error'] ?? map['message'] ?? '').toString();
      throw PlayFailure(msg.isEmpty ? 'Lagu tidak bisa diputar.' : msg, retryable: retryable);
    }
    String audio = '';
    final result = map['result'];
    if (result is Map) {
      final dl = result['download'];
      if (dl is Map && dl['audio'] != null) audio = dl['audio'].toString();
    }
    if (audio.isEmpty) throw const PlayFailure('Sumber audio tidak ditemukan.');
    var proxy = false;
    final i = audio.indexOf('#via-proxy');
    if (i >= 0) {
      audio = audio.substring(0, i);
      proxy = true;
    }
    if (audio.startsWith('local:')) proxy = true;
    return ResolvedAudio(audio, proxy);
  }

  static String _thumbUrl(Object? t) {
    if (t is String) return t;
    if (t is Map) return (t['url'] ?? '').toString();
    if (t is List && t.isNotEmpty) return _thumbUrl(t.last);
    return '';
  }

  /// /api/album?id=<MPRE.../playlistId> → daftar lagu (bentuk lagu sedikit berbeda dari pencarian).
  Future<AlbumData> album(String id) async {
    final r = await _api.get('/api/album', query: {'id': id});
    final res = r['result'];
    final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    final albumCover = _thumbUrl(m['thumbnails']);
    final songs = <Track>[];
    for (final j in _maps(m['songs'])) {
      final vid = (j['videoId'] ?? '').toString();
      if (vid.isEmpty) continue;
      final own = _thumbUrl(j['thumbnails'] ?? j['thumbnail']);
      songs.add(Track.fromSearch({
        ...j,
        'thumbnail': own.isNotEmpty ? own : albumCover,
        'album': (j['album'] ?? m['title'] ?? '').toString(),
      }));
    }
    return AlbumData(title: (m['title'] ?? '').toString(), cover: albumCover, songs: songs);
  }

  /// /api/artist?id=<UC...>. Item album/single/playlist: {name, artist, browseId, thumbnails}.
  Future<ArtistData> artist(String id) async {
    final r = await _api.get('/api/artist', query: {'id': id});
    final res = r['result'];
    final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
    final name = (m['name'] ?? '').toString();
    List<BrowseItem> items(Object? v, BrowseKind kind) => _maps(v)
        .map((j) => BrowseItem.fromJson({
              'id': (j['browseId'] ?? '').toString(),
              'title': (j['name'] ?? '').toString(),
              'artist': (j['artist'] ?? '').toString(),
              'cover': _thumbUrl(j['thumbnails']),
            }, kind))
        .where((e) => e.id.isNotEmpty)
        .toList();
    final songs = <Track>[];
    for (final j in _maps(m['topSongs'])) {
      if ((j['videoId'] ?? '').toString().isEmpty) continue;
      songs.add(Track.fromSearch({
        ...j,
        'thumbnail': _thumbUrl(j['thumbnails']),
        'artist': (j['artist'] ?? name).toString(),
        'artistId': id,
      }));
    }
    return ArtistData(
      name: name,
      cover: _thumbUrl(m['thumbnails']),
      topSongs: songs,
      albums: items(m['topAlbums'], BrowseKind.album),
      singles: items(m['topSingles'], BrowseKind.album),
      playlists: items(m['playlists'], BrowseKind.playlist),
      similar: items(m['similarArtists'], BrowseKind.artist),
    );
  }

  /// /api/lyrics → baris bertanda waktu (synced) atau teks biasa (plain).
  /// Pencarian khusus lagu; gagal = daftar kosong (dipakai Chart/Radio).
  Future<List<Track>> searchSongs(String query) async {
    try {
      final r = await search(query, type: 'songs');
      return r.songs.where((t) => t.videoId.isNotEmpty).toList();
    } catch (_) {
      return <Track>[];
    }
  }

  /// Buang duplikat berdasarkan videoId; [skipId] ikut dibuang.
  static List<Track> dedupe(List<Track> list, {String? skipId}) {
    final seen = <String>{if (skipId != null && skipId.isNotEmpty) skipId};
    return [
      for (final t in list)
        if (t.videoId.isNotEmpty && seen.add(t.videoId)) t,
    ];
  }

  /// Radio (sama seperti X.radio di web): cari artis, "judul artis", dan "artis mix",
  /// selang-seling hasilnya, buang duplikat, maksimal 30 lagu.
  Future<List<Track>> radio({String title = '', String artist = '', String? excludeId}) async {
    final qs = <String>[
      if (artist.isNotEmpty) artist,
      if (title.isNotEmpty) '$title $artist'.trim(),
      if (artist.isNotEmpty && title.isNotEmpty) '$artist mix',
    ];
    if (qs.isEmpty) return <Track>[];
    final res = await Future.wait(qs.map(searchSongs));
    final all = <Track>[];
    var max = 0;
    for (final r in res) {
      if (r.length > max) max = r.length;
    }
    for (var i = 0; i < max; i++) {
      for (final r in res) {
        if (i < r.length) all.add(r[i]);
      }
    }
    return dedupe(all, skipId: excludeId).take(30).toList();
  }

  /// Romanisasi lirik (POST /api/romanize). Hasil sejajar dengan [lines]; string kosong = tidak perlu.
  Future<List<String>> romanize(List<String> lines) async {
    final r = await _api.post('/api/romanize', data: {'lines': lines});
    final v = r['roman'];
    final out = v is List ? v.map((e) => (e ?? '').toString()).toList() : <String>[];
    while (out.length < lines.length) {
      out.add('');
    }
    return out;
  }

  /// Segmen non-musik (SponsorBlock). Gagal/tidak ada = daftar kosong.
  Future<List<SbSegment>> sponsorSegments(String videoId) async {
    final r = await _api.get('/api/sponsorblock', query: {'id': videoId}, soft401: true);
    return SbSegment.parse(r['segments']);
  }

  Future<Lyrics> lyrics(String id, String title, String artist) async {
    final cache = lyricsCache;
    Lyrics fresh;
    try {
      fresh = await _fetchLyrics(id, title, artist);
    } catch (e) {
      // Offline / server tak terjangkau: pakai lirik tersimpan bila ada.
      final saved = await cache?.read(id);
      if (saved != null) return saved;
      rethrow;
    }
    if (cache != null && cache.wants(id) && !fresh.isEmpty) {
      await cache.write(id, fresh);
    }
    return fresh;
  }

  Future<Lyrics> _fetchLyrics(String id, String title, String artist) async {
    final r = await _api.get('/api/lyrics', query: {'id': id, 'title': title, 'artist': artist});
    final res = r['result'];
    final l = (res is Map && res['lyrics'] is Map) ? Map<String, dynamic>.from(res['lyrics'] as Map) : <String, dynamic>{};
    final lines = _maps(l['lines'])
        .map((j) => LyricLine(
              time: j['time'] is num ? (j['time'] as num).toDouble() : 0,
              text: (j['text'] ?? '').toString(),
              translation: (j['translation'] ?? '').toString(),
            ))
        .toList();
    return Lyrics(type: (l['type'] ?? 'none').toString(), lines: lines);
  }
}
