import 'track.dart';

class HistEntry {
  const HistEntry({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.cover,
    required this.ts,
    required this.seconds,
  });

  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String cover;
  final int ts;
  final int seconds;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(ts);

  Track get track => Track(
        videoId: id,
        title: title,
        artist: artist,
        artistId: artistId,
        cover: coverFor(cover, id),
      );

  factory HistEntry.fromJson(Map<String, dynamic> j) => HistEntry(
        id: (j['id'] ?? '').toString(),
        title: (j['t'] ?? '').toString(),
        artist: (j['a'] ?? '').toString(),
        artistId: (j['aid'] ?? '').toString(),
        cover: (j['c'] ?? '').toString(),
        ts: j['ts'] is num ? (j['ts'] as num).toInt() : 0,
        seconds: j['s'] is num ? (j['s'] as num).toInt() : 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        't': title,
        'a': artist,
        'aid': artistId,
        'c': cover,
        'ts': ts,
        's': seconds,
      };
}
