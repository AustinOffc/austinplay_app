import 'package:flutter_test/flutter_test.dart';
import 'package:auzify/models/track.dart';
import 'package:auzify/services/music_service.dart';

Track _t(String id) => Track(videoId: id, title: 't$id', artist: 'a');

void main() {
  test('dedupe membuang duplikat, id kosong, dan skipId', () {
    final out = MusicService.dedupe([_t('a'), _t('b'), _t('a'), _t(''), _t('c')], skipId: 'b');
    expect(out.map((e) => e.videoId).toList(), ['a', 'c']);
  });

  test('dedupe tanpa skipId mempertahankan urutan', () {
    final out = MusicService.dedupe([_t('x'), _t('y'), _t('x')]);
    expect(out.map((e) => e.videoId).toList(), ['x', 'y']);
  });
}
