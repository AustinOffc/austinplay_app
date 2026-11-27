import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/lyrics.dart';

/// Cache lirik di penyimpanan privat app, hanya untuk lagu yang sudah diunduh
/// (supaya lirik tetap tampil saat offline). Satu berkas JSON per videoId.
class LyricsCache {
  Directory? _dir;

  /// Menentukan lagu mana yang layak disimpan liriknya (diisi dari DownloadService.has).
  bool Function(String videoId) wants = (_) => false;

  Future<void> init() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final d = Directory('${base.path}/lyrics');
      if (!await d.exists()) await d.create(recursive: true);
      _dir = d;
    } catch (_) {
      _dir = null;
    }
  }

  static String _safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');

  File? _file(String id) {
    final d = _dir;
    final s = _safeId(id);
    if (d == null || s.isEmpty) return null;
    return File('${d.path}/$s.json');
  }

  Future<Lyrics?> read(String id) async {
    final f = _file(id);
    if (f == null) return null;
    try {
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map) return null;
      final l = Lyrics.fromJson(Map<String, dynamic>.from(j));
      return l.isEmpty ? null : l;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String id, Lyrics l) async {
    final f = _file(id);
    if (f == null || l.isEmpty) return;
    try {
      await f.writeAsString(jsonEncode(l.toJson()), flush: true);
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    final f = _file(id);
    if (f == null) return;
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
