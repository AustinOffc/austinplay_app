import 'track.dart';

const int kPlaylistMax = 15;

class Playlist {
  const Playlist({required this.id, required this.name, this.image = '', this.songs = const []});

  final String id;
  final String name;
  final String image;
  final List<Track> songs;

  String get cover {
    if (image.isNotEmpty) return image;
    return songs.isNotEmpty ? songs.first.cover : '';
  }

  Playlist copyWith({String? name, String? image, List<Track>? songs}) => Playlist(
        id: id,
        name: name ?? this.name,
        image: image ?? this.image,
        songs: songs ?? this.songs,
      );

  factory Playlist.fromJson(Map<String, dynamic> j) {
    final raw = j['songs'];
    final songs = <Track>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final t = Track.fromJson(Map<String, dynamic>.from(e));
          if (t.videoId.isNotEmpty) songs.add(t);
        }
      }
    }
    return Playlist(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      image: (j['image'] ?? '').toString(),
      songs: songs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'songs': songs.map((e) => e.toJson()).toList(),
      };
}

class LikedArtist {
  const LikedArtist({required this.artistId, required this.name, this.thumbnail = ''});

  final String artistId;
  final String name;
  final String thumbnail;

  factory LikedArtist.fromJson(Map<String, dynamic> j) => LikedArtist(
        artistId: (j['artistId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        thumbnail: (j['thumbnail'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'artistId': artistId, 'name': name, 'thumbnail': thumbnail};
}

class OfflineEntry {
  const OfflineEntry({
    required this.track,
    required this.savedAt,
    this.manual = false,
    this.pl = const [],
  });

  final Track track;
  final int savedAt;
  final bool manual;
  final List<String> pl;

  String get id => track.videoId;

  OfflineEntry copyWith({bool? manual, List<String>? pl}) => OfflineEntry(
        track: track,
        savedAt: savedAt,
        manual: manual ?? this.manual,
        pl: pl ?? this.pl,
      );

  factory OfflineEntry.fromJson(Map<String, dynamic> j) {
    final p = j['pl'];
    return OfflineEntry(
      track: Track.fromJson(j),
      savedAt: j['savedAt'] is num ? (j['savedAt'] as num).toInt() : 0,
      manual: j['manual'] == true,
      pl: p is List ? p.map((e) => e.toString()).toList() : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        ...track.toJson(),
        'savedAt': savedAt,
        if (manual) 'manual': true,
        if (pl.isNotEmpty) 'pl': pl,
      };
}

class OfflinePlaylist {
  const OfflinePlaylist({required this.id, required this.savedAt});
  final String id;
  final int savedAt;

  factory OfflinePlaylist.fromJson(Map<String, dynamic> j) => OfflinePlaylist(
        id: (j['id'] ?? '').toString(),
        savedAt: j['savedAt'] is num ? (j['savedAt'] as num).toInt() : 0,
      );

  Map<String, dynamic> toJson() => {'id': id, 'savedAt': savedAt};
}
