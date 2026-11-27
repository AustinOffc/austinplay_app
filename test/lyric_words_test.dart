import 'package:flutter_test/flutter_test.dart';
import 'package:auzify/core/lyric_words.dart';

void main() {
  test('splitWords: rentang kata berurutan 0..1 dan spasi dipertahankan', () {
    final w = splitWords('Hello big world');
    expect(w.map((e) => e.text).toList(), ['Hello', 'big', 'world']);
    expect(w.first.a, 0);
    expect(w.last.b, closeTo(1, 1e-9));
    for (var i = 1; i < w.length; i++) {
      expect(w[i].a, closeTo(w[i - 1].b, 1e-9));
    }
    expect(w.map((e) => e.text + e.gap).join(), 'Hello big world');
  });

  test('splitWords: CJK tanpa spasi dipecah per karakter', () {
    final w = splitWords('こんにちは世界');
    expect(w.length, 7);
  });

  test('splitWords: teks kosong', () {
    expect(splitWords('   '), isEmpty);
  });

  test('lyricLineDuration dibatasi oleh jarak ke baris berikut', () {
    expect(lyricLineDuration(10, 11, 'x'), closeTo(0.88, 1e-9));
    expect(lyricLineDuration(0, null, 'Lorem ipsum dolor sit amet consectetur'), greaterThan(1.4));
    expect(lyricLineDuration(0, 0.1, 'a'), greaterThanOrEqualTo(0.5));
  });
}
