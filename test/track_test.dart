import 'package:auzify/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('durasi "3.45" = 225 detik', () {
    final t = Track.fromSearch({'videoId': 'abc', 'title': 'A &amp; B', 'duration': '3.45'});
    expect(t.durationSeconds, 225);
    expect(t.durationLabel, '3:45');
    expect(t.title, 'A & B');
    expect(t.cover, 'https://i.ytimg.com/vi/abc/hqdefault.jpg');
  });

  test('toJson sama dengan bentuk web', () {
    final j = const Track(videoId: 'x', title: 't', artist: 'a').toJson();
    expect(j['id'], 'x');
    expect(j['ytUrl'], 'https://youtube.com/watch?v=x');
  });
}
