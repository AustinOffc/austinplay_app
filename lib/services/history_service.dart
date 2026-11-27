import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/local_store.dart';
import '../models/hist_entry.dart';
import '../models/track.dart';

class _Session {
  _Session(this.id, this.last);
  final String id;
  double sec = 0;
  double last;
  int? entryTs;
  int saved = 0;
  Track? track;
}

class HistoryService {
  HistoryService(this._store);

  final LocalStore _store;
  static const String key = 'auz_hist';
  static const int max = 1000;

  final ValueNotifier<int> version = ValueNotifier<int>(0);
  _Session? _s;

  List<Map<String, dynamic>> _raw() {
    final out = <Map<String, dynamic>>[];
    for (final e in _store.list(key)) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
    }
    return out;
  }

  List<HistEntry> entries() => _raw()
      .map(HistEntry.fromJson)
      .where((e) => e.id.isNotEmpty && e.ts > 0)
      .toList();

  List<Track> recentUnique(int n) {
    final seen = <String>{};
    final out = <Track>[];
    for (final e in entries()) {
      if (out.length >= n) break;
      if (seen.add(e.id)) out.add(e.track);
    }
    return out;
  }

  void notifyExternalChange() => version.value++;

  void onPosition(Track t, Duration pos, bool playing, Duration? total) {
    if (!playing) return;
    var s = _s;
    final nowSec = pos.inMilliseconds / 1000.0;
    if (s == null || s.id != t.videoId) {
      flush();
      s = _Session(t.videoId, nowSec)..track = t;
      _s = s;
    }
    final d = nowSec - s.last;
    if (d > 0 && d < 2.5) s.sec += d;
    s.last = nowSec;
    final totalSec = total == null || total.inSeconds <= 0 ? 60.0 : total.inSeconds.toDouble();
    final need = totalSec * 0.5 < 30 ? totalSec * 0.5 : 30.0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (s.entryTs == null && s.sec >= need) {
      final e = HistEntry(
        id: t.videoId,
        title: t.title,
        artist: t.artist,
        artistId: t.artistId,
        cover: t.cover,
        ts: nowMs,
        seconds: s.sec.round(),
      );
      final arr = _raw();
      arr.insert(0, e.toJson());
      if (arr.length > max) arr.removeRange(max, arr.length);
      _store.put(key, jsonEncode(arr));
      s.entryTs = nowMs;
      s.saved = nowMs;
      version.value++;
    } else if (s.entryTs != null && nowMs - s.saved > 10000) {
      _saveEntry();
    }
  }

  void _saveEntry() {
    final s = _s;
    if (s == null || s.entryTs == null) return;
    final arr = _raw();
    for (var i = 0; i < arr.length && i < 5; i++) {
      if (arr[i]['ts'] == s.entryTs && arr[i]['id'] == s.id) {
        arr[i]['s'] = s.sec.round();
        _store.put(key, jsonEncode(arr));
        break;
      }
    }
    s.saved = DateTime.now().millisecondsSinceEpoch;
    version.value++;
  }

  void flush() {
    _saveEntry();
    _s = null;
  }

  void pauseSession() {
    _saveEntry();
  }

  Future<void> clear() async {
    await _store.put('auz_hist_reset', DateTime.now().millisecondsSinceEpoch.toString());
    await _store.put(key, '[]');
    _s = null;
    version.value++;
  }
}
