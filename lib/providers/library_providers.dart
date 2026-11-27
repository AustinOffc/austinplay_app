import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/local_store.dart';
import '../models/playlist.dart';
import '../models/sb_segment.dart';
import '../models/track.dart';
import '../services/download_service.dart';
import '../services/history_service.dart';
import '../services/sync_service.dart';
import 'music_providers.dart';

final localStoreProvider =
    Provider<LocalStore>((ref) => throw UnimplementedError('localStoreProvider belum di-override'));

final syncServiceProvider =
    Provider<SyncService>((ref) => throw UnimplementedError('syncServiceProvider belum di-override'));

final historyServiceProvider = Provider<HistoryService>(
    (ref) => throw UnimplementedError('historyServiceProvider belum di-override'));

final downloadServiceProvider = Provider<DownloadService>(
    (ref) => throw UnimplementedError('downloadServiceProvider belum di-override'));

enum AddResult { added, exists, full }

@immutable
class LibraryState {
  const LibraryState({
    this.songs = const [],
    this.artists = const [],
    this.playlists = const [],
    this.offline = const [],
    this.offlinePlaylists = const [],
  });

  final List<Track> songs;
  final List<LikedArtist> artists;
  final List<Playlist> playlists;
  final List<OfflineEntry> offline;
  final List<OfflinePlaylist> offlinePlaylists;

  bool isLiked(String videoId) => songs.any((s) => s.videoId == videoId);
  bool isArtistLiked(String artistId) => artistId.isNotEmpty && artists.any((a) => a.artistId == artistId);
  Playlist? playlistById(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isOfflinePlaylist(String id) => offlinePlaylists.any((p) => p.id == id);
}

class LibraryController extends Notifier<LibraryState> {
  static const kSongs = 'austin_liked_songs';
  static const kArtists = 'austin_liked_artists';
  static const kPlaylists = 'austin_playlists';
  static const kOffline = 'pwa_offline_tracks';
  static const kOfflinePl = 'pwa_offline_playlists';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  LibraryState build() {
    final sub = ref.read(syncServiceProvider).changed.listen((keys) {
      reload();
      if (keys.contains(kOffline) || keys.contains(kOfflinePl)) unawaited(backfillMissing());
    });
    ref.onDispose(sub.cancel);
    return _read();
  }

  List<T> _map<T>(String key, T Function(Map<String, dynamic>) f) {
    final out = <T>[];
    for (final e in _store.list(key)) {
      if (e is Map) {
        try {
          out.add(f(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
    }
    return out;
  }

  LibraryState _read() => LibraryState(
        songs: _map<Track>(kSongs, Track.fromJson).where((t) => t.videoId.isNotEmpty).toList(),
        artists: _map<LikedArtist>(kArtists, LikedArtist.fromJson)
            .where((a) => a.artistId.isNotEmpty)
            .toList(),
        playlists: _map<Playlist>(kPlaylists, Playlist.fromJson).where((p) => p.id.isNotEmpty).toList(),
        offline: _map<OfflineEntry>(kOffline, OfflineEntry.fromJson)
            .where((e) => e.track.videoId.isNotEmpty)
            .toList(),
        offlinePlaylists: _map<OfflinePlaylist>(kOfflinePl, OfflinePlaylist.fromJson)
            .where((e) => e.id.isNotEmpty)
            .toList(),
      );

  void reload() {
    state = _read();
    ref.read(historyServiceProvider).notifyExternalChange();
  }

  Future<void> _saveSongs(List<Track> v) async {
    state = LibraryState(
        songs: v,
        artists: state.artists,
        playlists: state.playlists,
        offline: state.offline,
        offlinePlaylists: state.offlinePlaylists);
    await _store.put(kSongs, jsonEncode(v.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveArtists(List<LikedArtist> v) async {
    state = LibraryState(
        songs: state.songs,
        artists: v,
        playlists: state.playlists,
        offline: state.offline,
        offlinePlaylists: state.offlinePlaylists);
    await _store.put(kArtists, jsonEncode(v.map((e) => e.toJson()).toList()));
  }

  Future<void> _savePlaylists(List<Playlist> v) async {
    state = LibraryState(
        songs: state.songs,
        artists: state.artists,
        playlists: v,
        offline: state.offline,
        offlinePlaylists: state.offlinePlaylists);
    await _store.put(kPlaylists, jsonEncode(v.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveOffline(List<OfflineEntry> v) async {
    state = LibraryState(
        songs: state.songs,
        artists: state.artists,
        playlists: state.playlists,
        offline: v,
        offlinePlaylists: state.offlinePlaylists);
    await _store.put(kOffline, jsonEncode(v.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveOfflinePl(List<OfflinePlaylist> v) async {
    state = LibraryState(
        songs: state.songs,
        artists: state.artists,
        playlists: state.playlists,
        offline: state.offline,
        offlinePlaylists: v);
    await _store.put(kOfflinePl, jsonEncode(v.map((e) => e.toJson()).toList()));
  }

  Future<bool> toggleLike(Track t) async {
    final list = [...state.songs];
    final i = list.indexWhere((s) => s.videoId == t.videoId);
    if (i >= 0) {
      list.removeAt(i);
      await _saveSongs(list);
      return false;
    }
    list.insert(0, t);
    await _saveSongs(list);
    return true;
  }

  Future<bool> toggleLikeArtist(String artistId, String name, String thumbnail) async {
    if (artistId.isEmpty) return false;
    final list = [...state.artists];
    final i = list.indexWhere((a) => a.artistId == artistId);
    if (i >= 0) {
      list.removeAt(i);
      await _saveArtists(list);
      return false;
    }
    list.insert(0, LikedArtist(artistId: artistId, name: name, thumbnail: thumbnail));
    await _saveArtists(list);
    return true;
  }

  Future<Playlist> createPlaylist(String name, {Track? first}) async {
    final p = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Playlist baru' : name.trim(),
      songs: first == null ? const [] : [first],
    );
    await _savePlaylists([p, ...state.playlists]);
    return p;
  }

  /// Simpan seluruh album/playlist sebagai playlist baru (padanan Album.importPlaylist di web).
  /// Dibatasi [kPlaylistMax] lagu; mengembalikan playlist dan jumlah lagu yang terpotong.
  Future<({Playlist playlist, int dropped})> createPlaylistFromSongs(
      String name, String image, List<Track> songs) async {
    final seen = <String>{};
    final unique = <Track>[
      for (final t in songs)
        if (t.videoId.isNotEmpty && seen.add(t.videoId)) t,
    ];
    final kept = unique.take(kPlaylistMax).toList();
    final p = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Playlist baru' : name.trim(),
      image: image,
      songs: kept,
    );
    await _savePlaylists([p, ...state.playlists]);
    return (playlist: p, dropped: unique.length - kept.length);
  }

  Future<void> renamePlaylist(String id, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await _savePlaylists([
      for (final p in state.playlists) p.id == id ? p.copyWith(name: n) : p,
    ]);
  }

  Future<void> setPlaylistImage(String id, String image) async {
    await _savePlaylists([
      for (final p in state.playlists) p.id == id ? p.copyWith(image: image) : p,
    ]);
  }

  Future<void> deletePlaylist(String id) async {
    await removeOfflinePlaylist(id);
    await _savePlaylists(state.playlists.where((p) => p.id != id).toList());
  }

  Future<AddResult> addToPlaylist(String id, Track t) async {
    final p = state.playlistById(id);
    if (p == null) return AddResult.exists;
    if (p.songs.any((s) => s.videoId == t.videoId)) return AddResult.exists;
    if (p.songs.length >= kPlaylistMax) return AddResult.full;
    await _savePlaylists([
      for (final x in state.playlists) x.id == id ? x.copyWith(songs: [...x.songs, t]) : x,
    ]);
    return AddResult.added;
  }

  Future<void> removeFromPlaylist(String id, String videoId) async {
    await _savePlaylists([
      for (final x in state.playlists)
        x.id == id ? x.copyWith(songs: x.songs.where((s) => s.videoId != videoId).toList()) : x,
    ]);
  }

  Future<void> _upsertOffline(Track t, {String? plId}) async {
    final list = [...state.offline];
    final i = list.indexWhere((e) => e.id == t.videoId);
    if (i >= 0) {
      final cur = list[i];
      if (plId == null) {
        list[i] = cur.copyWith(manual: true);
      } else if (!cur.pl.contains(plId)) {
        list[i] = cur.copyWith(pl: [...cur.pl, plId]);
      }
    } else {
      list.insert(
        0,
        OfflineEntry(
          track: t,
          savedAt: DateTime.now().millisecondsSinceEpoch,
          manual: plId == null,
          pl: plId == null ? const [] : [plId],
        ),
      );
    }
    await _saveOffline(list);
  }

  Future<bool> downloadTrack(Track t, {String? plId}) async {
    final ds = ref.read(downloadServiceProvider);
    final ok = await ds.download(t);
    if (ok) {
      await _upsertOffline(t, plId: plId);
      // Simpan lirik untuk offline (diam-diam; gagal tidak masalah).
      unawaited(ref
          .read(musicServiceProvider)
          .lyrics(t.videoId, t.title, t.artist)
          .then<void>((_) {}, onError: (Object _) {}));
    }
    return ok;
  }

  Future<int> downloadPlaylist(Playlist p) async {
    final ds = ref.read(downloadServiceProvider);
    if (!state.isOfflinePlaylist(p.id)) {
      await _saveOfflinePl([
        OfflinePlaylist(id: p.id, savedAt: DateTime.now().millisecondsSinceEpoch),
        ...state.offlinePlaylists,
      ]);
    }
    var done = 0;
    for (final t in p.songs) {
      if (ds.has(t.videoId)) {
        await _upsertOffline(t, plId: p.id);
        done++;
        continue;
      }
      if (await downloadTrack(t, plId: p.id)) done++;
    }
    return done;
  }

  Future<void> removeOffline(String videoId) async {
    await ref.read(downloadServiceProvider).remove(videoId);
    await _saveOffline(state.offline.where((e) => e.id != videoId).toList());
  }

  Future<void> removeOfflinePlaylist(String plId) async {
    if (!state.isOfflinePlaylist(plId)) return;
    final ds = ref.read(downloadServiceProvider);
    final keep = <OfflineEntry>[];
    for (final e in state.offline) {
      if (!e.pl.contains(plId)) {
        keep.add(e);
        continue;
      }
      final rest = e.pl.where((x) => x != plId).toList();
      if (rest.isEmpty && !e.manual) {
        await ds.remove(e.id);
      } else {
        keep.add(e.copyWith(pl: rest));
      }
    }
    await _saveOffline(keep);
    await _saveOfflinePl(state.offlinePlaylists.where((p) => p.id != plId).toList());
  }

  Future<void> clearOffline() async {
    await ref.read(downloadServiceProvider).removeAll();
    await _saveOffline(const []);
    await _saveOfflinePl(const []);
  }

  bool _backfilling = false;

  Future<int> backfillMissing({bool force = false, int limit = 25}) async {
    if (_backfilling) return 0;
    final ds = ref.read(downloadServiceProvider);
    if (!await ds.isOnline()) return 0;
    if (!force && !await ds.onUnmetered()) return 0;
    _backfilling = true;
    var done = 0;
    try {
      final todo = state.offline.where((e) => !ds.has(e.id)).take(limit).toList();
      for (final e in todo) {
        if (await ds.download(e.track)) done++;
      }
    } finally {
      _backfilling = false;
    }
    return done;
  }
}

final libraryProvider = NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

final isLikedProvider =
    Provider.family<bool, String>((ref, id) => ref.watch(libraryProvider.select((s) => s.isLiked(id))));

final isOfflineReadyProvider = Provider.family<bool, String>((ref, id) {
  ref.watch(downloadVersionProvider);
  return ref.read(downloadServiceProvider).has(id);
});

final downloadVersionProvider = StreamProvider<int>((ref) {
  final ds = ref.watch(downloadServiceProvider);
  final c = StreamController<int>();
  void l() => c.add(ds.version.value);
  ds.version.addListener(l);
  ref.onDispose(() {
    ds.version.removeListener(l);
    c.close();
  });
  c.add(ds.version.value);
  return c.stream;
});

final onlineProvider = StreamProvider<bool>((ref) async* {
  final ds = ref.watch(downloadServiceProvider);
  yield await ds.isOnline();
  yield* ds.onlineStream;
});

class SettingsState {
  const SettingsState({
    this.autoNext = true,
    this.rate = 1.0,
    this.sponsorBlock = true,
    this.sbCats = SbSegment.defaultCategories,
  });
  final bool autoNext;
  final double rate;
  final bool sponsorBlock;
  final List<String> sbCats;

  SettingsState copyWith({bool? autoNext, double? rate, bool? sponsorBlock, List<String>? sbCats}) =>
      SettingsState(
        autoNext: autoNext ?? this.autoNext,
        rate: rate ?? this.rate,
        sponsorBlock: sponsorBlock ?? this.sponsorBlock,
        sbCats: sbCats ?? this.sbCats,
      );
}

class SettingsController extends Notifier<SettingsState> {
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  SettingsState build() {
    final sub = ref.read(syncServiceProvider).changed.listen((keys) {
      if (keys.contains('austin_auto_next') || keys.contains('austin_playback_rate')) {
        state = _read();
        _apply();
      }
    });
    ref.onDispose(sub.cancel);
    final s = _read();
    Future.microtask(() => _apply(s));
    return s;
  }

  SettingsState _read() {
    final a = _store.get('austin_auto_next');
    final r = double.tryParse(_store.get('austin_playback_rate') ?? '');
    final sb = _store.get('auz_sb');
    List<String> cats = SbSegment.defaultCategories;
    final raw = _store.get('auz_sb_cats');
    if (raw != null && raw.isNotEmpty) {
      try {
        final v = jsonDecode(raw);
        if (v is List) cats = v.map((e) => e.toString()).where(SbSegment.labels.containsKey).toList();
      } catch (_) {}
    }
    return SettingsState(
      autoNext: a == null ? true : a == 'true',
      rate: (r == null || r < 0.5 || r > 2.0) ? 1.0 : r,
      sponsorBlock: sb == null ? true : sb == 'true',
      sbCats: cats,
    );
  }

  void _apply([SettingsState? s]) {
    final v = s ?? state;
    final h = ref.read(audioHandlerProvider);
    h.autoNext = v.autoNext;
    h.sponsorBlock = v.sponsorBlock;
    h.sbCategories = v.sbCats.toSet();
    h.sbLoader ??= ref.read(musicServiceProvider).sponsorSegments;
    unawaited(h.setSpeed(v.rate));
  }

  Future<void> setAutoNext(bool v) async {
    state = state.copyWith(autoNext: v);
    _apply();
    await _store.put('austin_auto_next', v ? 'true' : 'false');
  }

  Future<void> setRate(double v) async {
    state = state.copyWith(rate: v);
    _apply();
    await _store.put('austin_playback_rate', v.toString());
  }

  /// SponsorBlock: pengaturan lokal perangkat (tidak disinkronkan), seperti di web.
  Future<void> setSponsorBlock(bool v) async {
    state = state.copyWith(sponsorBlock: v);
    _apply();
    ref.read(audioHandlerProvider).refreshSponsorBlock();
    await _store.put('auz_sb', v ? 'true' : 'false');
  }

  Future<void> toggleSbCategory(String cat) async {
    final cur = [...state.sbCats];
    if (!cur.remove(cat)) cur.add(cat);
    state = state.copyWith(sbCats: cur);
    _apply();
    await _store.put('auz_sb_cats', jsonEncode(cur));
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

final historyVersionProvider = StreamProvider<int>((ref) {
  final h = ref.watch(historyServiceProvider);
  final c = StreamController<int>();
  void l() => c.add(h.version.value);
  h.version.addListener(l);
  ref.onDispose(() {
    h.version.removeListener(l);
    c.close();
  });
  c.add(h.version.value);
  return c.stream;
});

final recentTracksProvider = Provider<List<Track>>((ref) {
  ref.watch(historyVersionProvider);
  return ref.read(historyServiceProvider).recentUnique(10);
});
