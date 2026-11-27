import 'track.dart';

enum BrowseKind { playlist, album, artist }

/// Playlist / album / artis dari hasil pencarian: {id, title, artist, cover, ...}.
class BrowseItem {
  const BrowseItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.kind,
  });

  final String id;
  final String title;
  final String subtitle;
  final String cover;
  final BrowseKind kind;

  factory BrowseItem.fromJson(Map<String, dynamic> j, BrowseKind kind) {
    String s(Object? v) => v == null ? '' : v.toString();
    final sub = s(j['artist']);
    final type = s(j['albumType']);
    final year = s(j['year']);
    final parts = <String>[
      if (kind == BrowseKind.album && type.isNotEmpty) type,
      if (sub.isNotEmpty) sub,
      if (kind == BrowseKind.album && year.isNotEmpty) year,
    ];
    return BrowseItem(
      id: s(j['id']),
      title: s(j['title'] ?? j['name']),
      subtitle: parts.join(' • '),
      cover: s(j['cover'] ?? j['thumbnail']),
      kind: kind,
    );
  }
}

class SearchResult {
  const SearchResult({
    this.songs = const [],
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
  });

  final List<Track> songs;
  final List<BrowseItem> albums;
  final List<BrowseItem> playlists;
  final List<BrowseItem> artists;

  List<BrowseItem> get playlistsAndAlbums => [...playlists, ...albums];
  bool get isEmpty =>
      songs.isEmpty && albums.isEmpty && playlists.isEmpty && artists.isEmpty;
}

/// Isi album / playlist dari /api/album.
class AlbumData {
  const AlbumData({required this.title, required this.cover, required this.songs});
  final String title;
  final String cover;
  final List<Track> songs;
}

/// Halaman artis dari /api/artist.
class ArtistData {
  const ArtistData({
    required this.name,
    required this.cover,
    required this.topSongs,
    required this.albums,
    required this.singles,
    required this.playlists,
    required this.similar,
  });
  final String name;
  final String cover;
  final List<Track> topSongs;
  final List<BrowseItem> albums;
  final List<BrowseItem> singles;
  final List<BrowseItem> playlists;
  final List<BrowseItem> similar;
}
