class LyricLine {
  const LyricLine({required this.time, required this.text, this.translation = ''});
  final double time; // detik
  final String text;
  final String translation;

  factory LyricLine.fromJson(Map<String, dynamic> j) => LyricLine(
        time: j['t'] is num ? (j['t'] as num).toDouble() : 0,
        text: (j['x'] ?? '').toString(),
        translation: (j['tr'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        't': time,
        'x': text,
        if (translation.isNotEmpty) 'tr': translation,
      };
}

/// type: 'synced' | 'plain' | 'none'
class Lyrics {
  const Lyrics({required this.type, required this.lines});
  final String type;
  final List<LyricLine> lines;
  bool get synced => type == 'synced';
  bool get isEmpty => lines.isEmpty || type == 'none';

  factory Lyrics.fromJson(Map<String, dynamic> j) {
    final raw = j['lines'];
    return Lyrics(
      type: (j['type'] ?? 'none').toString(),
      lines: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => LyricLine.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <LyricLine>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}
