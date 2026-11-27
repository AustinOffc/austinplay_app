String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

String _str(Object? v) => v == null ? '' : v.toString();

/// Sampul HD; bila kosong pakai thumbnail YouTube dari videoId.
String coverFor(String? url, String videoId) {
  if (url != null && url.isNotEmpty) return url;
  return videoId.isEmpty ? '' : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
}

/// Lagu. Bentuk JSON (toJson/fromJson) SAMA dengan web agar sinkron akun kompatibel:
/// {id, videoId, title, artist, artistId, cover, ytUrl, album?, albumId?, duration?}
class Track {
  const Track({
    required this.videoId,
    required this.title,
    required this.artist,
    this.artistId = '',
    this.cover = '',
    this.album = '',
    this.albumId = '',
    this.duration = '',
  });

  final String videoId;
  final String title;
  final String artist;
  final String artistId;
  final String cover;
  final String album;
  final String albumId;

  /// Format server: "3.45" (menit.detik).
  final String duration;

  String get id => videoId;
  String get ytUrl => 'https://youtube.com/watch?v=$videoId';

  int? get durationSeconds {
    final d = duration.trim();
    if (d.isEmpty) return null;
    if (d.contains(':')) {
      final p = d.split(':').map(int.tryParse).toList();
      if (p.any((e) => e == null)) return null;
      if (p.length == 2) return p[0]! * 60 + p[1]!;
      if (p.length == 3) return p[0]! * 3600 + p[1]! * 60 + p[2]!;
      return null;
    }
    final p = d.split('.');
    if (p.length == 2) {
      final m = int.tryParse(p[0]);
      final s = int.tryParse(p[1]);
      if (m != null && s != null) return m * 60 + s;
    }
    return null;
  }

  /// "3:45" untuk ditampilkan.
  String get durationLabel {
    final s = durationSeconds;
    if (s == null) return '';
    final m = s ~/ 60;
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  factory Track.fromSearch(Map<String, dynamic> j) {
    final id = _str(j['videoId']);
    return Track(
      videoId: id,
      title: _unescape(_str(j['title'])),
      artist: _unescape(_str(j['artist'])),
      artistId: _str(j['artistId']),
      cover: coverFor(_str(j['thumbnail']), id),
      album: _unescape(_str(j['album'])),
      albumId: _str(j['albumId']),
      duration: _str(j['duration']),
    );
  }

  factory Track.fromJson(Map<String, dynamic> j) {
    final id = _str(j['videoId'] ?? j['id']);
    return Track(
      videoId: id,
      title: _str(j['title']),
      artist: _str(j['artist']),
      artistId: _str(j['artistId']),
      cover: coverFor(_str(j['cover']), id),
      album: _str(j['album']),
      albumId: _str(j['albumId']),
      duration: _str(j['duration']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': videoId,
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'artistId': artistId,
        'cover': cover,
        'ytUrl': ytUrl,
        if (album.isNotEmpty) 'album': album,
        if (albumId.isNotEmpty) 'albumId': albumId,
        if (duration.isNotEmpty) 'duration': duration,
      };
}
