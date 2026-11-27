import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/local_store.dart';
import '../core/storage.dart';

class _Srv {
  const _Srv(this.value, this.updatedAt);
  final String value;
  final int updatedAt;
}

class SyncService {
  SyncService(this._api, this._store, this._tokens) {
    _store.onChanged = _onLocalChange;
  }

  final ApiClient _api;
  final LocalStore _store;
  final TokenStore _tokens;
  int? userId;

  static const List<String> keys = [
    'austin_liked_songs',
    'austin_liked_artists',
    'austin_playlists',
    'pwa_offline_tracks',
    'pwa_offline_playlists',
    'austin_auto_next',
    'austin_playback_rate',
    'auz_hist_reset',
    'auz_hist',
  ];
  static const Set<String> arrayKeys = {
    'austin_liked_songs',
    'austin_liked_artists',
    'austin_playlists',
    'pwa_offline_tracks',
    'pwa_offline_playlists',
    'auz_hist',
  };
  static const int histMax = 1000;
  static const Duration pollEvery = Duration(seconds: 60);

  final StreamController<Set<String>> _changed = StreamController<Set<String>>.broadcast();
  final ValueNotifier<DateTime?> lastSync = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String> error = ValueNotifier<String>('');
  final ValueNotifier<bool> busyNotifier = ValueNotifier<bool>(false);

  Timer? _pushTimer;
  Timer? _pollTimer;
  bool _busy = false;
  bool _again = false;

  Stream<Set<String>> get changed => _changed.stream;

  void _onLocalChange(String key) {
    if (!_tokens.hasToken || !keys.contains(key)) return;
    final meta = _store.readMeta();
    meta[key] = SyncMeta(DateTime.now().millisecondsSinceEpoch, true);
    unawaited(_store.writeMeta(meta));
    _pushSoon(key == 'auz_hist' ? const Duration(seconds: 20) : const Duration(milliseconds: 1500));
  }

  void _pushSoon([Duration d = const Duration(milliseconds: 1500)]) {
    if (!_tokens.hasToken) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(d, () => unawaited(sync()));
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollEvery, (_) => unawaited(sync()));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pushTimer?.cancel();
    _pushTimer = null;
  }

  Future<void> onSignedOut() async {
    stopPolling();
    await _store.clearSyncState();
    lastSync.value = null;
  }

  static String _idOf(Object? o) {
    if (o is Map) {
      final v = o['id'] ?? o['videoId'] ?? o['artistId'] ?? o['name'];
      return v != null && v.toString().isNotEmpty ? v.toString() : jsonEncode(o);
    }
    return o.toString();
  }

  static List<dynamic> _decodeList(String? s) {
    if (s == null || s.isEmpty) return <dynamic>[];
    try {
      final v = jsonDecode(s);
      return v is List ? v : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  static bool _nonEmptyList(String? s) => _decodeList(s).isNotEmpty;

  static dynamic _deepCopy(Object? v) => jsonDecode(jsonEncode(v));

  @visibleForTesting
  static List<dynamic> mergePlaylists(List<dynamic> local, List<dynamic> server) {
    final byId = <String, Map<String, dynamic>>{};
    final out = <Map<String, dynamic>>[];
    for (final p in [...local, ...server]) {
      if (p is! Map || p['id'] == null || p['id'].toString().isEmpty) continue;
      final id = p['id'].toString();
      final existing = byId[id];
      if (existing == null) {
        final copy = Map<String, dynamic>.from(_deepCopy(p) as Map);
        copy['songs'] = copy['songs'] is List ? copy['songs'] : <dynamic>[];
        byId[id] = copy;
        out.add(copy);
        continue;
      }
      final songs = existing['songs'] as List<dynamic>;
      final seen = <String>{
        for (final s in songs)
          if (s is Map) (s['videoId'] ?? s['id']).toString(),
      };
      final more = p['songs'];
      if (more is List) {
        for (final s in more) {
          if (s is! Map) continue;
          final key = (s['videoId'] ?? s['id']).toString();
          if (!seen.contains(key) && songs.length < 15) {
            songs.add(s);
            seen.add(key);
          }
        }
      }
      final img = existing['image'];
      if ((img == null || img.toString().isEmpty) && p['image'] != null) {
        existing['image'] = p['image'];
      }
    }
    return out;
  }

  @visibleForTesting
  static String mergeHist(String? a, String? b, int reset) {
    final map = <String, Map<String, dynamic>>{};
    final out = <Map<String, dynamic>>[];
    for (final str in [a, b]) {
      for (final e in _decodeList(str)) {
        if (e is! Map) continue;
        final id = e['id'];
        final ts = e['ts'];
        if (id == null || ts is! num || ts <= reset) continue;
        final k = '$id|${ts.toInt()}';
        final cur = map[k];
        if (cur == null) {
          final copy = Map<String, dynamic>.from(e);
          map[k] = copy;
          out.add(copy);
        } else {
          final s1 = e['s'] is num ? (e['s'] as num) : 0;
          final s0 = cur['s'] is num ? (cur['s'] as num) : 0;
          if (s1 > s0) cur['s'] = e['s'];
        }
      }
    }
    out.sort((x, y) {
      final c = (y['ts'] as num).compareTo(x['ts'] as num);
      if (c != 0) return c;
      return x['id'].toString().compareTo(y['id'].toString());
    });
    if (out.length > histMax) out.removeRange(histMax, out.length);
    return jsonEncode(out);
  }

  static List<dynamic> mergeArrays(String key, List<dynamic> local, List<dynamic> server) {
    if (key == 'austin_playlists') return mergePlaylists(local, server);
    final seen = <String>{};
    final out = <dynamic>[];
    for (final o in [...local, ...server]) {
      final id = _idOf(o);
      if (seen.add(id)) out.add(o);
    }
    return out;
  }

  static String _valueForPush(String key, String raw) {
    if (key != 'pwa_offline_tracks') return raw;
    try {
      final arr = jsonDecode(raw);
      if (arr is List) {
        for (final o in arr) {
          if (o is Map) o.remove('lyrics');
        }
        return jsonEncode(arr);
      }
    } catch (_) {}
    return raw;
  }

  Future<void> _applyLocal(
      String key, String value, int t, Map<String, SyncMeta> meta, Set<String> changed) async {
    await _store.putApplied(key, value);
    meta[key] = SyncMeta(t, false);
    changed.add(key);
  }

  Future<bool> sync() async {
    if (!_tokens.hasToken) return false;
    final uid = userId;
    if (uid == null) return false;
    if (_busy) {
      _again = true;
      return false;
    }
    _busy = true;
    busyNotifier.value = true;
    error.value = '';
    final changed = <String>{};
    var ok = false;
    try {
      final res = await _api.get('/api/sync', soft401: false);
      final raw = res['data'];
      final server = <String, _Srv>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map && v['value'] is String) {
            final u = v['updatedAt'];
            server[k.toString()] = _Srv(v['value'] as String, u is num ? u.toInt() : 0);
          }
        });
      }
      final meta = _store.readMeta();
      final bootstrap = _store.get('ap_sync_uid') != uid.toString();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final k in keys) {
        final local = _store.get(k);
        final s = server[k];
        final m = meta[k] ?? const SyncMeta(0, false);

        if (k == 'auz_hist') {
          if (local == null && s == null) continue;
          final localReset = int.tryParse(_store.get('auz_hist_reset') ?? '') ?? 0;
          final srvReset = int.tryParse(server['auz_hist_reset']?.value ?? '') ?? 0;
          final reset = max(localReset, srvReset);
          final merged = mergeHist(local, s?.value, reset);
          if (merged != local) {
            await _store.putApplied(k, merged);
            changed.add(k);
          }
          if (s == null || merged != s.value) {
            meta[k] = SyncMeta(now, true);
          } else {
            meta[k] = SyncMeta(s.updatedAt, false);
          }
          continue;
        }

        if (bootstrap) {
          if (s != null && local != null && arrayKeys.contains(k) && _nonEmptyList(local)) {
            String merged;
            try {
              merged = jsonEncode(mergeArrays(k, _decodeList(local), _decodeList(s.value)));
            } catch (_) {
              merged = s.value;
            }
            await _store.putApplied(k, merged);
            meta[k] = SyncMeta(now, true);
            changed.add(k);
          } else if (s != null) {
            await _applyLocal(k, s.value, s.updatedAt, meta, changed);
          } else if (local != null && (!arrayKeys.contains(k) || _nonEmptyList(local))) {
            meta[k] = SyncMeta(now, true);
          }
          continue;
        }

        if (s != null && s.updatedAt > m.t) {
          await _applyLocal(k, s.value, s.updatedAt, meta, changed);
        } else if (m.d && (s == null || m.t >= s.updatedAt)) {
          meta[k] = m;
        } else if (s == null && m.t == 0 && arrayKeys.contains(k) && _nonEmptyList(local)) {
          meta[k] = SyncMeta(now, true);
        }
      }

      if (bootstrap) await _store.putApplied('ap_sync_uid', uid.toString());
      await _store.writeMeta(meta);

      final items = <String, dynamic>{};
      final sentT = <String, int>{};
      for (final k in keys) {
        final m = meta[k];
        if (m == null || !m.d) continue;
        final raw = _store.get(k);
        if (raw == null) continue;
        items[k] = {'value': _valueForPush(k, raw), 'updatedAt': m.t};
        sentT[k] = m.t;
      }

      if (items.isNotEmpty) {
        final pr = await _api.put('/api/sync', data: {'items': items});
        final d = pr['data'];
        final m2 = _store.readMeta();
        if (d is Map) {
          for (final entry in d.entries) {
            final k = entry.key.toString();
            final v = entry.value;
            if (v is! Map || v['value'] is! String) continue;
            final value = v['value'] as String;
            final u = v['updatedAt'] is num ? (v['updatedAt'] as num).toInt() : 0;
            if (v['applied'] == true) {
              final cur = m2[k];
              if (cur != null && cur.t == sentT[k]) m2[k] = SyncMeta(u, false);
            } else if (k == 'auz_hist') {
              final rs = int.tryParse(_store.get('auz_hist_reset') ?? '') ?? 0;
              final mg = mergeHist(_store.get(k), value, rs);
              await _store.putApplied(k, mg);
              if (mg != value) {
                m2[k] = SyncMeta(DateTime.now().millisecondsSinceEpoch, true);
                _again = true;
              } else {
                m2[k] = SyncMeta(u, false);
              }
              changed.add(k);
            } else {
              await _applyLocal(k, value, u, m2, changed);
            }
          }
        }
        await _store.writeMeta(m2);
      }

      lastSync.value = DateTime.now();
      if (changed.isNotEmpty) _changed.add(changed);
      ok = true;
    } on ApiException catch (e) {
      if (e.status != 401) error.value = e.message;
    } catch (_) {
      error.value = 'Gagal sinkron.';
    } finally {
      _busy = false;
      busyNotifier.value = false;
      if (_again) {
        _again = false;
        _pushSoon();
      }
    }
    return ok;
  }
}
