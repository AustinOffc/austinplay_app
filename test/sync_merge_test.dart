import 'dart:convert';
import 'package:auzify/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mergeHist: union, buang yang <= reset, urut terbaru, ambil detik terbesar', () {
    final a = jsonEncode([
      {'id': 'x', 'ts': 300, 's': 10},
      {'id': 'y', 'ts': 100, 's': 5},
    ]);
    final b = jsonEncode([
      {'id': 'x', 'ts': 300, 's': 40},
      {'id': 'z', 'ts': 200, 's': 7},
    ]);
    final out = jsonDecode(SyncService.mergeHist(a, b, 100)) as List;
    expect(out.length, 2);
    expect(out[0]['id'], 'x');
    expect(out[0]['s'], 40);
    expect(out[1]['id'], 'z');
  });

  test('mergePlaylists: gabung lagu per id, maksimal 15, tanpa duplikat', () {
    List<Map<String, dynamic>> songs(int from, int to) =>
        [for (var i = from; i < to; i++) {'id': 'v$i', 'videoId': 'v$i', 'title': 't$i'}];
    final local = [
      {'id': 'pl_1', 'name': 'A', 'image': '', 'songs': songs(0, 10)}
    ];
    final server = [
      {'id': 'pl_1', 'name': 'A', 'image': 'img', 'songs': songs(5, 20)},
      {'id': 'pl_2', 'name': 'B', 'image': '', 'songs': songs(0, 2)},
    ];
    final out = SyncService.mergePlaylists(local, server);
    expect(out.length, 2);
    final first = out.first as Map;
    expect((first['songs'] as List).length, 15);
    expect(first['image'], 'img');
  });

  test('mergeArrays: duplikat dibuang berdasarkan id', () {
    final out = SyncService.mergeArrays('austin_liked_songs', [
      {'videoId': 'a'}
    ], [
      {'videoId': 'a'},
      {'videoId': 'b'}
    ]);
    expect(out.length, 2);
  });
}
