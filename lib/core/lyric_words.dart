import 'dart:math' as math;

/// Satu kata pada baris lirik: [a]..[b] = rentang relatif (0..1) di dalam baris, [gap] = spasi sesudahnya.
class LyricWord {
  const LyricWord(this.text, this.a, this.b, this.gap);
  final String text;
  final double a;
  final double b;
  final String gap;
}

final RegExp _cjk = RegExp(r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uAC00-\uD7AF]');

/// Memecah baris jadi kata berbobot (CJK tanpa spasi dipecah per karakter) — meniru wrapWords() di web.
List<LyricWord> splitWords(String text) {
  final raw = text.trim();
  if (raw.isEmpty) return const <LyricWord>[];
  final List<String> toks;
  if (!RegExp(r'\s').hasMatch(raw) && _cjk.hasMatch(raw) && raw.runes.length > 4) {
    toks = raw.runes.map(String.fromCharCode).toList();
  } else {
    toks = RegExp(r'\s+|\S+').allMatches(raw).map((m) => m.group(0)!).toList();
  }
  final words = <String>[];
  final gaps = <String>[];
  final weights = <double>[];
  for (final t in toks) {
    if (t.trim().isEmpty) {
      if (gaps.isNotEmpty) gaps[gaps.length - 1] = gaps.last + t;
      continue;
    }
    words.add(t);
    gaps.add('');
    weights.add(math.max(1, t.runes.length).toDouble() * (_cjk.hasMatch(t) ? 1.6 : 1.0));
  }
  final total = weights.fold<double>(0, (s, w) => s + w);
  if (total <= 0) return const <LyricWord>[];
  final out = <LyricWord>[];
  var acc = 0.0;
  for (var i = 0; i < words.length; i++) {
    final a = acc / total;
    acc += weights[i];
    out.add(LyricWord(words[i], a, acc / total, gaps[i]));
  }
  return out;
}

/// Perkiraan lama baris dinyanyikan (detik): sumber lirik hanya per baris, jadi ini hanya taksiran.
double lyricLineDuration(double start, double? next, String text) {
  final span = math.max(0.6, (next ?? start + 4) - start);
  final dur = math.min(span - 0.12, math.max(1.4, text.length * 0.085 + 0.4));
  return math.max(0.5, dur);
}
