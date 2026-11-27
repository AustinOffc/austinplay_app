import 'package:share_plus/share_plus.dart';
import '../models/track.dart';
import 'config.dart';

/// Tautan yang sama dengan web: /play/<id>, /artist/<id>, /album/<id>.
/// Backend menyajikan preview (judul + cover) dari query string, dan app membukanya lewat App Links.
String trackLink(Track t) {
  final q = Uri(queryParameters: {
    'title': t.title,
    'artist': t.artist,
    if (t.cover.startsWith('http')) 'cover': t.cover,
  }).query;
  return AppConfig.absUrl('/play/${t.videoId}?$q') ?? '';
}

String artistLink(String id, String name) {
  final q = Uri(queryParameters: {'name': name}).query;
  return AppConfig.absUrl('/artist/${Uri.encodeComponent(id)}?$q') ?? '';
}

String albumLink(String id, String title) {
  final q = Uri(queryParameters: {'title': title}).query;
  return AppConfig.absUrl('/album/${Uri.encodeComponent(id)}?$q') ?? '';
}

Future<void> shareTrack(Track t) => Share.share('${t.title} — ${t.artist}\n${trackLink(t)}');

Future<void> shareArtist(String id, String name) =>
    Share.share('$name di Auzify\n${artistLink(id, name)}');

Future<void> shareAlbum(String id, String title) =>
    Share.share('$title di Auzify\n${albumLink(id, title)}');
