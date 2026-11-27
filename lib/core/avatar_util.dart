import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Batas server untuk foto profil (src/routes/auth.routes.js: AVATAR_MAX).
const int kAvatarMaxBytes = 150 * 1024;

/// Pangkas persegi di tengah → 256×256 → JPEG ≤ 150 KB. null bila gambar tidak terbaca.
Uint8List? _processAvatar(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height ? oriented.width : oriented.height;
  if (side <= 0) return null;
  final x = (oriented.width - side) ~/ 2;
  final y = (oriented.height - side) ~/ 2;
  final square = img.copyCrop(oriented, x: x, y: y, width: side, height: side);
  final small = img.copyResize(square,
      width: 256, height: 256, interpolation: img.Interpolation.average);
  for (var q = 88; q >= 40; q -= 12) {
    final out = Uint8List.fromList(img.encodeJpg(small, quality: q));
    if (out.length <= kAvatarMaxBytes) return out;
  }
  return null;
}

/// Siapkan foto profil dari byte gambar apa pun → data URL JPEG siap unggah (null = gagal).
/// Dikerjakan di isolate supaya UI tidak macet.
Future<String?> prepareAvatarDataUrl(Uint8List bytes) async {
  final out = await compute(_processAvatar, bytes);
  if (out == null) return null;
  return 'data:image/jpeg;base64,${base64Encode(out)}';
}

/// Batas ukuran cover playlist. Seluruh daftar playlist disinkronkan sebagai satu nilai
/// (maks 600.000 karakter di server), jadi cover dibuat kecil.
const int kCoverMaxBytes = 40 * 1024;

Uint8List? _processCover(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height ? oriented.width : oriented.height;
  if (side <= 0) return null;
  final x = (oriented.width - side) ~/ 2;
  final y = (oriented.height - side) ~/ 2;
  final square = img.copyCrop(oriented, x: x, y: y, width: side, height: side);
  final small = img.copyResize(square,
      width: 320, height: 320, interpolation: img.Interpolation.average);
  for (var q = 82; q >= 34; q -= 12) {
    final out = Uint8List.fromList(img.encodeJpg(small, quality: q));
    if (out.length <= kCoverMaxBytes) return out;
  }
  return null;
}

/// Siapkan cover playlist dari byte gambar → data URL JPEG kecil (null = gagal).
Future<String?> prepareCoverDataUrl(Uint8List bytes) async {
  final out = await compute(_processCover, bytes);
  if (out == null) return null;
  return 'data:image/jpeg;base64,${base64Encode(out)}';
}
