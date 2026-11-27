/// Segmen non-musik dari /api/sponsorblock (`{start, end, category}` dalam detik).
class SbSegment {
  SbSegment(this.start, this.end, this.category);

  final double start;
  final double end;
  final String category;

  /// true bila sudah dilewati (direset bila pengguna memundurkan posisi sebelum segmen).
  bool done = false;

  static const Map<String, String> labels = {
    'sponsor': 'Sponsor',
    'selfpromo': 'Promosi diri',
    'interaction': 'Ajakan interaksi',
    'intro': 'Intro',
    'outro': 'Outro',
    'music_offtopic': 'Bagian non-musik',
  };

  static const List<String> defaultCategories = [
    'sponsor',
    'selfpromo',
    'interaction',
    'music_offtopic',
  ];

  static String label(String category) => labels[category] ?? 'segmen';

  static List<SbSegment> parse(Object? raw) {
    if (raw is! List) return <SbSegment>[];
    final out = <SbSegment>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final s = e['start'];
      final en = e['end'];
      if (s is! num || en is! num) continue;
      final cat = (e['category'] ?? '').toString();
      if (cat.isEmpty || en <= s) continue;
      out.add(SbSegment(s.toDouble(), en.toDouble(), cat));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }
}
