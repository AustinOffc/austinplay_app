import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'library_providers.dart';
import 'music_providers.dart';

class LyricsPrefs {
  const LyricsPrefs({this.words = true, this.roman = false, this.offsets = const {}});
  final bool words;
  final bool roman;

  /// videoId → geser waktu (detik). + = lirik muncul lebih cepat.
  final Map<String, double> offsets;

  double offsetFor(String videoId) => offsets[videoId] ?? 0;
}

/// Pengaturan alat lirik; tersimpan lokal (auz_words, auz_roman, auz_lyr_off) seperti di web, tidak disinkronkan.
class LyricsPrefsController extends Notifier<LyricsPrefs> {
  @override
  LyricsPrefs build() {
    final s = ref.read(localStoreProvider);
    final offsets = <String, double>{};
    final raw = s.get('auz_lyr_off');
    if (raw != null && raw.isNotEmpty) {
      try {
        final v = jsonDecode(raw);
        if (v is Map) {
          v.forEach((k, val) {
            if (val is num && val != 0) offsets[k.toString()] = val.toDouble();
          });
        }
      } catch (_) {}
    }
    return LyricsPrefs(
      words: s.get('auz_words') != 'false',
      roman: s.get('auz_roman') == 'true',
      offsets: offsets,
    );
  }

  Future<void> setWords(bool v) async {
    state = LyricsPrefs(words: v, roman: state.roman, offsets: state.offsets);
    await ref.read(localStoreProvider).put('auz_words', v ? 'true' : 'false');
  }

  Future<void> setRoman(bool v) async {
    state = LyricsPrefs(words: state.words, roman: v, offsets: state.offsets);
    await ref.read(localStoreProvider).put('auz_roman', v ? 'true' : 'false');
  }

  Future<void> nudge(String videoId, double delta) async {
    final cur = state.offsetFor(videoId);
    final next = ((cur + delta) * 100).round() / 100;
    await _setOffset(videoId, next.clamp(-10.0, 10.0).toDouble());
  }

  Future<void> resetOffset(String videoId) => _setOffset(videoId, 0);

  Future<void> _setOffset(String videoId, double v) async {
    final m = Map<String, double>.of(state.offsets);
    if (v == 0) {
      m.remove(videoId);
    } else {
      m[videoId] = v;
    }
    while (m.length > 300) {
      m.remove(m.keys.first);
    }
    state = LyricsPrefs(words: state.words, roman: state.roman, offsets: m);
    await ref.read(localStoreProvider).put('auz_lyr_off', jsonEncode(m));
  }
}

final lyricsPrefsProvider =
    NotifierProvider<LyricsPrefsController, LyricsPrefs>(LyricsPrefsController.new);

final RegExp _nonLatin = RegExp(r'[^\u0000-\u024F\u2000-\u206F]');

/// Romanisasi per baris (string kosong = tidak perlu). Kunci sama dengan [lyricsProvider]; di-cache selama sesi.
final romanProvider = FutureProvider.family<List<String>, (String, String, String)>((ref, k) async {
  final l = await ref.watch(lyricsProvider(k).future);
  if (l.isEmpty) return const <String>[];
  final texts = [for (final e in l.lines) e.text];
  if (!texts.any(_nonLatin.hasMatch)) return List<String>.filled(texts.length, '');
  return ref.read(musicServiceProvider).romanize(texts);
});
