import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/api_client.dart';
import '../models/track.dart';
import 'lyrics_cache.dart';
import 'music_service.dart';

class DownloadService {
  DownloadService(this._api, this._source);

  final ApiClient _api;
  final StreamSource _source;

  /// Diisi di main.dart; lirik ikut dihapus saat unduhan dihapus.
  LyricsCache? lyricsCache;

  Directory? _dir;
  final Set<String> _have = <String>{};
  final Map<String, CancelToken> _cancel = <String, CancelToken>{};

  final ValueNotifier<Map<String, double>> progress =
      ValueNotifier<Map<String, double>>(<String, double>{});
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  /// Unduhan yang dijeda (berkas .part disimpan; dilanjutkan dengan header Range).
  final ValueNotifier<Set<String>> paused = ValueNotifier<Set<String>>(<String>{});
  final Set<String> _pauseReq = <String>{};
  final Map<String, String> _pausedUrl = <String, String>{};
  String lastError = '';

  Future<void> init() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final d = Directory('${base.path}/offline');
      if (!await d.exists()) await d.create(recursive: true);
      _dir = d;
      await for (final f in d.list()) {
        if (f is File && f.path.endsWith('.mp3')) {
          final name = f.uri.pathSegments.last;
          _have.add(name.substring(0, name.length - 4));
        } else if (f is File && f.path.endsWith('.part')) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } catch (_) {
      _dir = null;
    }
  }

  bool has(String id) => _have.contains(id);

  bool isBusy(String id) => _cancel.containsKey(id);

  String? pathOf(String id) {
    final d = _dir;
    if (d == null || !_have.contains(id)) return null;
    return '${d.path}/$id.mp3';
  }

  Set<String> get ids => Set<String>.unmodifiable(_have);

  void _setProgress(String id, double? v) {
    final m = Map<String, double>.from(progress.value);
    if (v == null) {
      m.remove(id);
    } else {
      m[id] = v;
    }
    progress.value = m;
  }

  static String _safeName(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^A-Za-z0-9 _\-]'), '').trim();
    return cleaned.isEmpty ? 'lagu' : cleaned;
  }

  void _setPaused(String id, bool v) {
    final m = Set<String>.from(paused.value);
    if (v ? m.add(id) : m.remove(id)) paused.value = m;
  }

  bool isPaused(String id) => paused.value.contains(id);

  /// Jeda unduhan yang sedang berjalan (data yang sudah masuk disimpan).
  void pause(String id) {
    if (!_cancel.containsKey(id)) return;
    _pauseReq.add(id);
    _cancel[id]?.cancel();
  }

  Future<bool> download(Track t) async {
    final dir = _dir;
    if (dir == null) {
      lastError = 'Penyimpanan perangkat tidak tersedia.';
      return false;
    }
    final id = t.videoId;
    if (_have.contains(id)) return true;
    if (_cancel.containsKey(id)) return false;
    final token = CancelToken();
    _cancel[id] = token;
    _pauseReq.remove(id);
    _setProgress(id, 0);
    final part = File('${dir.path}/$id.part');
    var offset = 0;
    var keepPart = false;
    IOSink? sink;
    try {
      String url;
      final saved = _pausedUrl[id];
      if (paused.value.contains(id) && saved != null && await part.exists()) {
        url = saved;
        offset = await part.length();
      } else {
        final r = await _source.resolve(id);
        final name = '${_safeName(t.title)}.mp3';
        url = '/api/proxy-audio?url=${Uri.encodeComponent(r.audio)}&dl=${Uri.encodeComponent(name)}';
        if (await part.exists()) await part.delete();
      }
      _setPaused(id, false);
      _pausedUrl[id] = url;

      final res = await _api.dio.get<ResponseBody>(
        url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 120),
          headers: offset > 0 ? {'Range': 'bytes=$offset-'} : null,
          extra: {'soft401': true},
        ),
      );
      final body = res.data;
      if (body == null) {
        lastError = 'Unduhan gagal.';
        return false;
      }
      // 206 = server melanjutkan dari offset; 200 = Range diabaikan → mulai dari awal.
      final resumed = res.statusCode == 206 && offset > 0;
      var received = resumed ? offset : 0;
      var total = 0;
      final cr = res.headers.value('content-range');
      if (cr != null && cr.contains('/')) {
        total = int.tryParse(cr.substring(cr.lastIndexOf('/') + 1)) ?? 0;
      }
      if (total == 0) {
        final cl = int.tryParse(res.headers.value('content-length') ?? '') ?? 0;
        if (cl > 0) total = resumed ? offset + cl : cl;
      }
      final w = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      sink = w;
      await for (final chunk in body.stream) {
        w.add(chunk);
        received += chunk.length;
        if (total > 0) _setProgress(id, received / total);
      }
      await w.flush();
      await w.close();
      sink = null;

      final size = await part.length();
      if (size < 10 * 1024) {
        await part.delete();
        lastError = 'File audio tidak valid.';
        return false;
      }
      final out = File('${dir.path}/$id.mp3');
      if (await out.exists()) await out.delete();
      await part.rename(out.path);
      _have.add(id);
      _pausedUrl.remove(id);
      version.value++;
      return true;
    } on PlayFailure catch (e) {
      lastError = e.message;
      return false;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) && _pauseReq.contains(id)) {
        keepPart = true;
        lastError = 'Unduhan dijeda.';
      } else {
        lastError = CancelToken.isCancel(e) ? 'Unduhan dibatalkan.' : ApiClient.messageOf(e);
      }
      return false;
    } catch (_) {
      // Stream yang dibatalkan saat pause juga bisa berakhir di sini.
      if (token.isCancelled && _pauseReq.contains(id)) {
        keepPart = true;
        lastError = 'Unduhan dijeda.';
      } else {
        lastError = 'Unduhan gagal.';
      }
      return false;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      _cancel.remove(id);
      _setProgress(id, null);
      if (keepPart) {
        _setPaused(id, true);
      } else {
        _pausedUrl.remove(id);
        try {
          if (await part.exists()) await part.delete();
        } catch (_) {}
      }
      _pauseReq.remove(id);
    }
  }

  void cancel(String id) => _cancel[id]?.cancel();

  void cancelAll() {
    for (final t in _cancel.values) {
      t.cancel();
    }
  }

  Future<void> remove(String id) async {
    _pauseReq.remove(id);
    cancel(id);
    if (paused.value.contains(id)) {
      _setPaused(id, false);
      _pausedUrl.remove(id);
      final dir = _dir;
      if (dir != null) {
        try {
          final f = File('${dir.path}/$id.part');
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    final p = pathOf(id);
    _have.remove(id);
    await lyricsCache?.delete(id);
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    version.value++;
  }

  Future<void> removeAll() async {
    cancelAll();
    for (final id in _have.toList()) {
      await remove(id);
    }
  }

  Future<int> totalBytes() async {
    var n = 0;
    for (final id in _have) {
      final p = pathOf(id);
      if (p == null) continue;
      try {
        n += await File(p).length();
      } catch (_) {}
    }
    return n;
  }

  Future<bool> isOnline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.any((e) => e != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<bool> onUnmetered() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  Stream<bool> get onlineStream => Connectivity()
      .onConnectivityChanged
      .map((r) => r.any((e) => e != ConnectivityResult.none));
}
