import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../services/music_service.dart';
import 'library_providers.dart';
import 'music_providers.dart';

/// Tab Chart di Beranda (kunci, label, kueri) — sama dengan CHARTS di web.
const List<(String, String, String)> kCharts = [
  ('id', 'Indonesia', 'Top lagu Indonesia 2026'),
  ('gl', 'Global', 'Top hits global 2026'),
  ('vr', 'Viral', 'Lagu viral TikTok 2026'),
];

const Duration _chartTtl = Duration(hours: 6);

/// Hasil pencarian yang di-cache lokal 6 jam (kunci tidak disinkronkan).
/// Kalau pencarian baru gagal/kosong, cache lama (walau sudah kedaluwarsa) tetap dipakai
/// supaya Chart tidak kosong hanya karena YouTube sedang error.
Future<List<Track>> _cachedSongs(Ref ref, String key, String query, int limit) async {
  final store = ref.read(localStoreProvider);
  final raw = store.get(key);
  List<Track> stale = const [];
  if (raw != null && raw.isNotEmpty) {
    try {
      final v = jsonDecode(raw);
      if (v is Map && v['t'] is num && v['l'] is List) {
        final age = DateTime.now().millisecondsSinceEpoch - (v['t'] as num).toInt();
        final list = [
          for (final e in v['l'] as List)
            if (e is Map) Track.fromJson(Map<String, dynamic>.from(e)),
        ];
        if (age >= 0 && age < _chartTtl.inMilliseconds && list.isNotEmpty) return list;
        stale = list;
      }
    } catch (_) {}
  }
  final svc = ref.read(musicServiceProvider);
  var fresh = MusicService.dedupe(await svc.searchSongs(query)).take(limit).toList();
  if (fresh.isEmpty) {
    // coba sekali lagi setelah jeda singkat (server kadang baru selesai ganti jalur pencarian)
    await Future<void>.delayed(const Duration(seconds: 2));
    fresh = MusicService.dedupe(await svc.searchSongs(query)).take(limit).toList();
  }
  if (fresh.isNotEmpty) {
    await store.put(
      key,
      jsonEncode({
        't': DateTime.now().millisecondsSinceEpoch,
        'l': [for (final t in fresh) t.toJson()],
      }),
    );
    return fresh;
  }
  return stale;
}

final chartProvider = FutureProvider.family<List<Track>, String>((ref, key) {
  final c = kCharts.firstWhere((e) => e.$1 == key, orElse: () => kCharts.first);
  return _cachedSongs(ref, 'auz_chart_${c.$1}', c.$3, 12);
});

final topHitsProvider =
    FutureProvider<List<Track>>((ref) => _cachedSongs(ref, 'auz_tophits', 'Top hits 2026', 10));

/// Artis yang paling lama didengar (dari riwayat), untuk tombol "Radio <artis>".
final topArtistProvider = Provider<String?>((ref) {
  ref.watch(historyVersionProvider);
  final secs = <String, int>{};
  for (final e in ref.read(historyServiceProvider).entries()) {
    if (e.artist.isEmpty || e.artist == 'Unknown') continue;
    secs[e.artist] = (secs[e.artist] ?? 0) + e.seconds;
  }
  if (secs.isEmpty) return null;
  final best = secs.entries.reduce((a, b) => b.value > a.value ? b : a);
  return best.key;
});
