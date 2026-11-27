import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/browse.dart';
import '../models/lyrics.dart';
import '../models/track.dart';
import '../services/audio_handler.dart';
import '../services/music_service.dart';
import 'core_providers.dart';

/// Di-override di main() dengan handler yang sudah di-init lewat AudioService.init.
final audioHandlerProvider =
    Provider<AuzifyAudioHandler>((ref) => throw UnimplementedError('audioHandlerProvider belum di-override'));

final musicServiceProvider =
    Provider<MusicService>((ref) => MusicService(ref.watch(apiClientProvider)));

final mediaItemProvider =
    StreamProvider<MediaItem?>((ref) => ref.watch(audioHandlerProvider).mediaItem);

final playbackStateProvider =
    StreamProvider<PlaybackState>((ref) => ref.watch(audioHandlerProvider).playbackState);

final currentVideoIdProvider =
    Provider<String?>((ref) => ref.watch(mediaItemProvider).valueOrNull?.id);

final hasPlayerProvider =
    Provider<bool>((ref) => ref.watch(mediaItemProvider).valueOrNull != null);

class HomeData {
  const HomeData({required this.songs, required this.playlists});
  final List<Track> songs;
  final List<BrowseItem> playlists;
}

/// Sama seperti Home.fetch() di web: "Trend Indonesia" + playlist/album (acak).
final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final music = ref.watch(musicServiceProvider);
  final r = await music.search('Trend Indonesia', type: 'songs');
  var plist = <BrowseItem>[...r.playlists, ...r.albums];
  if (plist.length < 4) {
    const qs = ['Lagu Indonesia Populer', 'Top Hits Indonesia', 'Playlist Terbaik', 'Hits Viral Indonesia'];
    try {
      final r2 = await music.search(qs[Random().nextInt(qs.length)], type: 'playlists');
      plist = [...plist, ...r2.playlists, ...r2.albums];
    } catch (_) {}
  }
  plist.shuffle();
  return HomeData(songs: r.songs, playlists: plist);
});

const List<String> kPopularArtists = [
  'Twenty One Pilots',
  'Imagine Dragons',
  'Panic! At The Disco',
  'Fall Out Boy',
  'Hindia',
];

/// Artis populer (nama tetap seperti web; id & sampul diambil dari pencarian).
final popularArtistsProvider = FutureProvider<List<BrowseItem>>((ref) async {
  final music = ref.watch(musicServiceProvider);
  final out = await Future.wait(kPopularArtists.map((name) async {
    try {
      final r = await music.search(name, type: 'artists');
      if (r.artists.isEmpty) return null;
      return r.artists.firstWhere(
        (a) => a.title.toLowerCase().trim() == name.toLowerCase().trim(),
        orElse: () => r.artists.first,
      );
    } catch (_) {
      return null;
    }
  }));
  return out.whereType<BrowseItem>().toList();
});

const List<String> kCategories = [
  'Semua', 'Developer Profile', 'Chill', 'Focus', 'Commute', 'Gaming', 'Energize', 'Party',
  'Feel good', 'Romance', 'Workout', 'Sleep', 'Sad', 'Happy', 'Nostalgia', 'Acoustic', 'Pop', 'Rock',
];

String categoryQuery(String name) {
  switch (name) {
    case 'Developer Profile':
      return 'TWENTY ONE PILOTS';
    case 'Acoustic':
      return 'Acoustic Songs Hits';
    case 'Chill':
      return 'Chill Vibes Lofi Songs';
    case 'Focus':
      return 'Focus Deep Work Music';
    case 'Commute':
      return 'Driving Roadtrip Music';
    case 'Gaming':
      return 'Gaming EDM Hype Songs';
    case 'Energize':
      return 'Energetic Workout Beats';
    case 'Party':
      return 'Party Dance Hits';
    case 'Feel good':
      return 'Feel Good Happy Songs';
    case 'Romance':
      return 'Romantic Love Songs';
    case 'Workout':
      return 'Gym Workout Motivation Music';
    case 'Sleep':
      return 'Sleeping Calming Relaxation Music';
    case 'Sad':
      return 'Sad Melancholic Songs';
    case 'Happy':
      return 'Upbeat Happy Songs';
    case 'Nostalgia':
      return '2000s Hits Nostalgia Songs';
    default:
      return '$name Music';
  }
}

final categoryResultProvider = FutureProvider.family<SearchResult, String>((ref, name) {
  return ref.watch(musicServiceProvider).search(categoryQuery(name), type: 'all');
});

final albumProvider = FutureProvider.family<AlbumData, String>(
    (ref, id) => ref.watch(musicServiceProvider).album(id));

final artistProvider = FutureProvider.family<ArtistData, String>(
    (ref, id) => ref.watch(musicServiceProvider).artist(id));

/// Kunci (videoId, judul, artis) — record punya kesetaraan nilai.
final lyricsProvider = FutureProvider.family<Lyrics, (String, String, String)>(
    (ref, k) => ref.watch(musicServiceProvider).lyrics(k.$1, k.$2, k.$3));
