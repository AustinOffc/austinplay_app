import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncMeta {
  const SyncMeta(this.t, this.d);
  final int t;
  final bool d;
}

class LocalStore {
  LocalStore(this._p);
  final SharedPreferences _p;

  void Function(String key)? onChanged;
  bool applying = false;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  String? get(String key) => _p.getString(key);

  Future<void> put(String key, String value) async {
    await _p.setString(key, value);
    if (!applying) onChanged?.call(key);
  }

  Future<void> putApplied(String key, String value) async {
    applying = true;
    try {
      await _p.setString(key, value);
    } finally {
      applying = false;
    }
  }

  Future<void> remove(String key) => _p.remove(key);

  List<dynamic> list(String key) {
    final s = _p.getString(key);
    if (s == null || s.isEmpty) return <dynamic>[];
    try {
      final v = jsonDecode(s);
      return v is List ? v : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<void> putList(String key, List<dynamic> value) => put(key, jsonEncode(value));

  Map<String, SyncMeta> readMeta() {
    final out = <String, SyncMeta>{};
    final s = _p.getString('ap_sync_meta');
    if (s == null) return out;
    try {
      final m = jsonDecode(s);
      if (m is Map) {
        m.forEach((k, v) {
          if (v is Map) {
            final t = v['t'];
            out[k.toString()] = SyncMeta(t is num ? t.toInt() : 0, v['d'] == true);
          }
        });
      }
    } catch (_) {}
    return out;
  }

  Future<void> writeMeta(Map<String, SyncMeta> meta) => _p.setString(
        'ap_sync_meta',
        jsonEncode(meta.map((k, v) => MapEntry(k, {'t': v.t, 'd': v.d}))),
      );

  Future<void> clearSyncState() async {
    await _p.remove('ap_sync_meta');
    await _p.remove('ap_sync_uid');
  }
}
