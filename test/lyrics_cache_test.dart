import 'package:auzify/models/lyrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Lyrics toJson/fromJson bolak-balik (cache offline)', () {
    const l = Lyrics(type: 'synced', lines: [
      LyricLine(time: 1.5, text: 'halo', translation: 'hello'),
      LyricLine(time: 4, text: 'dunia'),
    ]);
    final back = Lyrics.fromJson(l.toJson());
    expect(back.type, 'synced');
    expect(back.lines.length, 2);
    expect(back.lines[0].time, 1.5);
    expect(back.lines[0].translation, 'hello');
    expect(back.lines[1].translation, '');
    expect(back.isEmpty, isFalse);
  });

  test('Lyrics.fromJson tahan data rusak', () {
    final l = Lyrics.fromJson({'type': 'plain', 'lines': 'bukan list'});
    expect(l.lines, isEmpty);
    expect(l.isEmpty, isTrue);
  });
}
