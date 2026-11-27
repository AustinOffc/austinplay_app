import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/sb_segment.dart';
import '../models/track.dart';
import 'history_service.dart';
import 'music_service.dart';

enum RepeatMode { off, all, one }

/// Keadaan timer tidur: hitung mundur [remaining], atau berhenti di akhir lagu [endOfTrack].
class SleepState {
  const SleepState({this.remaining, this.endOfTrack = false});
  final Duration? remaining;
  final bool endOfTrack;
  bool get active => remaining != null || endOfTrack;
}

/// Mesin audio: antrean sendiri, URL dibuka lewat /api/ytplay (bukan daftar URL statis).
/// Strategi (PROMPT 2.3): stage 0 URL langsung → stage 1 proxy → minta URL baru (refresh)
/// → bila tetap gagal: toast + lagu berikutnya. Stream putus di tengah lagu → lanjut dari posisi terakhir.
class AuzifyAudioHandler extends BaseAudioHandler with SeekHandler {
  AuzifyAudioHandler(this._source) {
    _wire();
  }

  final StreamSource _source;
  /// Equalizer Android (efek audio just_audio). Diatur lewat eqProvider.
  final AndroidEqualizer equalizer = AndroidEqualizer();
  late final AudioPlayer _player =
      AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]));
  final List<Track> _tracks = [];
  final List<int> _history = [];
  final Map<String, ResolvedAudio> _cache = {};
  final Random _rnd = Random();
  final StreamController<String> _errors = StreamController<String>.broadcast();

  int _index = -1;
  int _gen = 0;
  int _recoverCount = 0;
  int _failStreak = 0;
  int? _shuffleNext;
  bool _loading = false;

  final ValueNotifier<bool> shuffle = ValueNotifier<bool>(false);
  final ValueNotifier<RepeatMode> repeat = ValueNotifier<RepeatMode>(RepeatMode.off);
  bool autoNext = true;

  // ---- SponsorBlock ----
  bool sponsorBlock = false;
  Set<String> sbCategories = SbSegment.defaultCategories.toSet();
  Future<List<SbSegment>> Function(String videoId)? sbLoader;
  List<SbSegment> _sbSegs = <SbSegment>[];
  String _sbId = '';

  // ---- Timer tidur ----
  final ValueNotifier<SleepState> sleep = ValueNotifier<SleepState>(const SleepState());
  Timer? _sleepTimer;
  DateTime? _sleepEnd;

  /// Naik setiap kali isi antrean berubah (UI antrean mendengarkan ini).
  final ValueNotifier<int> queueVersion = ValueNotifier<int>(0);
  String? Function(String id)? localPath;
  HistoryService? history;

  /// true = tamu di Room: kontrol pemutar dikunci (hanya host yang mengatur).
  final ValueNotifier<bool> locked = ValueNotifier<bool>(false);

  /// Dipanggil saat tamu menekan play (di app, notifikasi, atau layar kunci) → "ikut host lagi".
  VoidCallback? onLockedPlay;
  DateTime _lockNoticeAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isPlaying => !_loading && _player.playing;
  Duration get position => _player.position;

  /// Pesan error untuk ditampilkan sebagai toast.
  Stream<String> get errors => _errors.stream;
  Track? get currentTrack => (_index >= 0 && _index < _tracks.length) ? _tracks[_index] : null;
  List<Track> get tracks => List.unmodifiable(_tracks);
  int get currentIndex => _index;

  void _wire() {
    _player.playbackEventStream.listen(_broadcast, onError: (Object e, StackTrace st) {
      _recover();
    });
    _player.positionStream.listen((pos) {
      _sbTick(pos);
      final t = currentTrack;
      final h = history;
      if (t == null || h == null || _loading) return;
      h.onPosition(t, pos, _player.playing, _player.duration);
    });
    _player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) _onCompleted();
    });
    _player.durationStream.listen((d) {
      final item = mediaItem.value;
      if (d != null && item != null && item.duration != d) {
        mediaItem.add(item.copyWith(duration: d));
      }
    });
    _broadcast();
  }

  // ---------- API untuk UI ----------

  void _lockNotice() {
    final now = DateTime.now();
    if (now.difference(_lockNoticeAt) < const Duration(seconds: 2)) return;
    _lockNoticeAt = now;
    _errors.add('Kamu tamu di Room — hanya host yang bisa mengatur pemutaran.');
  }

  /// Dipakai Room (tamu): ikuti lagu/posisi/status host. Melewati kunci.
  Future<void> followRoom(Track t, Duration pos, bool shouldPlay) async {
    final cur = currentTrack;
    if (cur == null || cur.videoId != t.videoId) {
      _tracks
        ..clear()
        ..add(t);
      _history.clear();
      _recoverCount = 0;
      _failStreak = 0;
      queue.add([_toItem(t)]);
      queueVersion.value++;
      await _playIndex(0, resumeAt: pos);
      if (!shouldPlay && currentTrack?.videoId == t.videoId) await _player.pause();
      return;
    }
    if (_loading) return;
    final drift = (_player.position - pos).abs();
    if (shouldPlay) {
      if (drift > const Duration(seconds: 2)) await _player.seek(pos);
      if (!_player.playing) unawaited(_player.play());
    } else {
      if (_player.playing) await _player.pause();
      if (drift > const Duration(seconds: 1)) await _player.seek(pos);
    }
  }

  Future<void> playQueue(List<Track> tracks, int start) async {
    if (tracks.isEmpty) return;
    if (locked.value) {
      _lockNotice();
      return;
    }
    _tracks
      ..clear()
      ..addAll(tracks);
    _history.clear();
    _recoverCount = 0;
    _failStreak = 0;
    queue.add(_tracks.map(_toItem).toList());
    queueVersion.value++;
    await _playIndex(start.clamp(0, tracks.length - 1).toInt());
  }

  void toggleShuffle() {
    if (locked.value) return;
    shuffle.value = !shuffle.value;
    _shuffleNext = null;
  }

  void cycleRepeat() {
    if (locked.value) return;
    repeat.value = RepeatMode.values[(repeat.value.index + 1) % RepeatMode.values.length];
    _shuffleNext = null;
  }

  // ---------- Antrean ----------

  void _queueChanged() {
    _history.clear();
    _shuffleNext = null;
    queue.add(_tracks.map(_toItem).toList());
    _broadcast();
    queueVersion.value++;
  }

  /// Putar setelah lagu ini. Antrean kosong → langsung diputar.
  Future<void> addNext(Track t) async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    if (_tracks.isEmpty || _index < 0) {
      await playQueue([t], 0);
      return;
    }
    _tracks.insert(_index + 1, t);
    _queueChanged();
  }

  /// Tambah di akhir antrean. Antrean kosong → langsung diputar.
  Future<void> addToEnd(Track t) async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    if (_tracks.isEmpty || _index < 0) {
      await playQueue([t], 0);
      return;
    }
    _tracks.add(t);
    _queueChanged();
  }

  /// Radio: bila [seed] sedang diputar, lagunya tidak terputus dan sisa antrean diganti [list];
  /// selain itu antrean baru diputar dari awal.
  Future<void> setRadio(Track? seed, List<Track> list) async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    final cur = currentTrack;
    if (seed != null && cur != null && cur.videoId == seed.videoId) {
      _tracks
        ..clear()
        ..add(cur)
        ..addAll(list);
      _index = 0;
      _queueChanged();
      return;
    }
    await playQueue([if (seed != null) seed, ...list], 0);
  }

  /// Hapus lagu dari antrean (lagu yang sedang diputar tidak bisa dihapus).
  void removeFromQueue(int i) {
    if (locked.value || i < 0 || i >= _tracks.length || i == _index) return;
    _tracks.removeAt(i);
    if (i < _index) _index--;
    _queueChanged();
  }

  /// Pindah urutan; [to] mengikuti semantik ReorderableListView (dihitung sebelum pencabutan).
  void moveInQueue(int from, int to) {
    if (locked.value) return;
    if (from < 0 || from >= _tracks.length || to < 0 || to > _tracks.length) return;
    if (to > from) to--;
    if (from == to) return;
    final cur = _index;
    final t = _tracks.removeAt(from);
    _tracks.insert(to, t);
    if (cur == from) {
      _index = to;
    } else if (from < cur && to >= cur) {
      _index = cur - 1;
    } else if (from > cur && to <= cur) {
      _index = cur + 1;
    }
    _queueChanged();
  }

  // ---------- Timer tidur ----------

  void startSleep(Duration d) {
    cancelSleep();
    _sleepEnd = DateTime.now().add(d);
    sleep.value = SleepState(remaining: d);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final end = _sleepEnd;
      if (end == null) return;
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) {
        unawaited(_fireSleep());
      } else {
        sleep.value = SleepState(remaining: left);
      }
    });
  }

  void sleepAtTrackEnd() {
    cancelSleep();
    sleep.value = const SleepState(endOfTrack: true);
  }

  void cancelSleep() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEnd = null;
    if (sleep.value.active) sleep.value = const SleepState();
  }

  Future<void> _fireSleep() async {
    cancelSleep();
    history?.pauseSession();
    try {
      for (var i = 9; i >= 0; i--) {
        await _player.setVolume(i / 10);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      await _player.pause();
    } finally {
      await _player.setVolume(1);
    }
  }

  // ---------- SponsorBlock ----------

  /// Panggil setelah pengaturan SponsorBlock berubah.
  void refreshSponsorBlock() {
    _sbSegs = <SbSegment>[];
    _sbId = '';
    final t = currentTrack;
    if (!sponsorBlock || t == null) return;
    unawaited(_loadSegments(t.videoId));
  }

  Future<void> _loadSegments(String id) async {
    final f = sbLoader;
    if (f == null) return;
    _sbId = id;
    try {
      final segs = await f(id);
      if (_sbId == id) _sbSegs = segs;
    } catch (_) {
      // opsional: gagal = tidak ada segmen
    }
  }

  void _sbTick(Duration pos) {
    if (!sponsorBlock || _sbSegs.isEmpty || _loading || locked.value || !_player.playing) return;
    final t = pos.inMilliseconds / 1000.0;
    for (final g in _sbSegs) {
      if (t < g.start - 2) g.done = false;
      if (g.done || !sbCategories.contains(g.category)) continue;
      if (t >= g.start && t < g.end - 0.25) {
        g.done = true;
        _errors.add('Dilewati: ${SbSegment.label(g.category)}');
        final dur = _player.duration;
        if (dur != null && g.end >= dur.inMilliseconds / 1000.0 - 1.5) {
          final n = _nextIndex();
          if (autoNext && n != null) {
            unawaited(_goTo(n));
          } else {
            unawaited(_player.seek(dur - const Duration(milliseconds: 200)));
          }
        } else {
          unawaited(_player.seek(Duration(milliseconds: (g.end * 1000).round())));
        }
        return;
      }
    }
  }

  // ---------- BaseAudioHandler ----------

  @override
  Future<void> play() async {
    if (locked.value) {
      onLockedPlay?.call();
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    history?.pauseSession();
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> skipToQueueItem(int index) async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    _recoverCount = 0;
    await _goTo(index);
  }

  @override
  Future<void> skipToNext() async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    _recoverCount = 0;
    final n = _nextIndex();
    if (n == null) return;
    await _goTo(n);
  }

  @override
  Future<void> skipToPrevious() async {
    if (locked.value) {
      _lockNotice();
      return;
    }
    _recoverCount = 0;
    if (_player.position > const Duration(seconds: 3) || _tracks.isEmpty) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_history.isNotEmpty) {
      await _playIndex(_history.removeLast());
    } else if (_index > 0) {
      await _playIndex(_index - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> stop() async {
    cancelSleep();
    _gen++;
    _loading = false;
    await _player.stop();
    await super.stop();
  }

  // ---------- Internal ----------

  Future<void> _goTo(int i) async {
    if (_index >= 0) _history.add(_index);
    if (_history.length > 200) _history.removeAt(0);
    await _playIndex(i);
  }

  int? _nextIndex() {
    if (_tracks.isEmpty) return null;
    if (repeat.value == RepeatMode.one && _index >= 0) return _index;
    if (shuffle.value && _tracks.length > 1) {
      // Ditentukan sekali per lagu supaya prefetch & next sepakat.
      if (_shuffleNext == null || _shuffleNext == _index) {
        int n;
        do {
          n = _rnd.nextInt(_tracks.length);
        } while (n == _index);
        _shuffleNext = n;
      }
      return _shuffleNext;
    }
    if (_index + 1 < _tracks.length) return _index + 1;
    if (repeat.value == RepeatMode.all) return 0;
    return null;
  }

  Future<void> _playIndex(int i, {Duration? resumeAt, bool forceRefresh = false}) async {
    if (i < 0 || i >= _tracks.length) return;
    final gen = ++_gen;
    _index = i;
    _shuffleNext = null;
    final t = _tracks[i];
    mediaItem.add(_toItem(t));
    _sbSegs = <SbSegment>[];
    _sbId = '';
    if (sponsorBlock) unawaited(_loadSegments(t.videoId));
    _loading = true;
    _broadcast();
    try {
      await _player.stop();
    } catch (_) {}
    if (gen != _gen) return;

    final lp = localPath?.call(t.videoId);
    if (lp != null) {
      final okLocal = await _tryFile(lp, resumeAt, gen);
      if (gen != _gen) return;
      if (okLocal) {
        _failStreak = 0;
        _prefetchNext();
        return;
      }
    }

    PlayFailure? fail;
    for (var attempt = 0; attempt < 2; attempt++) {
      final refresh = forceRefresh || attempt == 1;
      ResolvedAudio r;
      try {
        r = await _resolve(t.videoId, refresh: refresh);
      } on PlayFailure catch (e) {
        fail = e;
        if (!e.retryable) break;
        await Future<void>.delayed(const Duration(seconds: 1));
        if (gen != _gen) return;
        continue;
      }
      if (gen != _gen) return;
      final urls = (attempt == 0 && !refresh && !r.needProxy) ? [r.direct, r.proxy] : [r.proxy];
      for (final u in urls) {
        final ok = await _tryUrl(u, resumeAt, gen);
        if (gen != _gen) return;
        if (ok) {
          _failStreak = 0;
          _prefetchNext();
          return;
        }
      }
      _cache.remove(t.videoId);
    }

    if (gen != _gen) return;
    _loading = false;
    _broadcast();
    _errors.add(fail != null && fail.message.isNotEmpty
        ? fail.message
        : 'Lagu gagal diputar, lanjut ke berikutnya.');
    _failStreak++;
    final n = _nextIndex();
    if (autoNext && !locked.value && n != null && n != i && _failStreak < 5) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (gen == _gen) await _goTo(n);
    }
  }

  Future<bool> _tryUrl(String url, Duration? resumeAt, int gen) async {
    try {
      await _player.setUrl(url, initialPosition: resumeAt);
      if (gen != _gen) return true;
      _loading = false;
      _broadcast();
      unawaited(_player.play());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryFile(String path, Duration? resumeAt, int gen) async {
    try {
      await _player.setFilePath(path, initialPosition: resumeAt);
      if (gen != _gen) return true;
      _loading = false;
      _broadcast();
      unawaited(_player.play());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ResolvedAudio> _resolve(String id, {bool refresh = false}) async {
    if (!refresh) {
      final c = _cache[id];
      if (c != null && c.fresh) return c;
    }
    final r = await _source.resolve(id, refresh: refresh);
    _cache[id] = r;
    return r;
  }

  /// Hangatkan lagu berikutnya (server menyiapkan cache) supaya pindah lagu tanpa jeda panjang.
  void _prefetchNext() {
    final n = _nextIndex();
    if (n == null || n == _index) return;
    final id = _tracks[n].videoId;
    if (localPath?.call(id) != null) return;
    final c = _cache[id];
    if (c != null && c.fresh) return;
    _source.resolve(id, prefetch: true).then((r) {
      _cache[id] = r;
    }).catchError((Object _) {});
  }

  /// Stream putus di tengah lagu → muat ulang (URL baru) dan lanjut dari posisi terakhir.
  Future<void> _recover() async {
    if (_loading || _index < 0 || _recoverCount >= 2) return;
    _recoverCount++;
    final pos = _player.position;
    await _playIndex(_index, resumeAt: pos, forceRefresh: true);
  }

  void _onCompleted() {
    if (_loading || _index < 0) return;
    history?.flush();
    if (sleep.value.endOfTrack) {
      cancelSleep();
      unawaited(_player.pause());
      unawaited(_player.seek(Duration.zero));
      return;
    }
    if (locked.value) {
      // Tamu Room: lagu berikutnya ditentukan host.
      unawaited(_player.pause());
      return;
    }
    if (repeat.value == RepeatMode.one) {
      unawaited(_player.seek(Duration.zero));
      unawaited(_player.play());
      return;
    }
    final n = _nextIndex();
    if (autoNext && n != null) {
      unawaited(_goTo(n));
    } else {
      unawaited(_player.pause());
      unawaited(_player.seek(Duration.zero));
    }
  }

  MediaItem _toItem(Track t) {
    final secs = t.durationSeconds;
    return MediaItem(
      id: t.videoId,
      title: t.title,
      artist: t.artist,
      album: t.album.isEmpty ? null : t.album,
      artUri: t.cover.isEmpty ? null : Uri.tryParse(t.cover),
      duration: secs == null ? null : Duration(seconds: secs),
      extras: {'artistId': t.artistId, 'cover': t.cover},
    );
  }

  void _broadcast([PlaybackEvent? event]) {
    final playing = !_loading && _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _loading
          ? AudioProcessingState.loading
          : const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _index < 0 ? null : _index,
    ));
  }
}
