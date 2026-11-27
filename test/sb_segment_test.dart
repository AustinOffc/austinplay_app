import 'package:flutter_test/flutter_test.dart';
import 'package:auzify/models/sb_segment.dart';

void main() {
  test('SbSegment.parse membaca {start,end,category} dan mengurutkan', () {
    final segs = SbSegment.parse([
      {'start': 50, 'end': 60.5, 'category': 'outro'},
      {'start': 1, 'end': 5, 'category': 'sponsor'},
      {'start': 9, 'end': 3, 'category': 'sponsor'}, // end <= start: dibuang
      {'start': 'x', 'end': 3, 'category': 'sponsor'}, // tipe salah: dibuang
      'bukan map',
    ]);
    expect(segs.length, 2);
    expect(segs.first.category, 'sponsor');
    expect(segs.last.end, 60.5);
    expect(segs.first.done, isFalse);
  });

  test('SbSegment.parse tahan input bukan list', () {
    expect(SbSegment.parse(null), isEmpty);
    expect(SbSegment.parse({'a': 1}), isEmpty);
  });

  test('label kategori', () {
    expect(SbSegment.label('sponsor'), 'Sponsor');
    expect(SbSegment.label('aneh'), 'segmen');
  });
}
