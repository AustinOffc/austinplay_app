import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';

/// Cache kecil untuk cover berbentuk data URL (cover playlist kustom dari web/app),
/// supaya base64 tidak didekode ulang di setiap build.
final Map<String, Uint8List> _dataCache = <String, Uint8List>{};

Uint8List? _decodeDataUrl(String url) {
  final hit = _dataCache[url];
  if (hit != null) return hit;
  final i = url.indexOf(',');
  if (i < 0) return null;
  try {
    final bytes = base64Decode(url.substring(i + 1));
    if (_dataCache.length >= 24) _dataCache.remove(_dataCache.keys.first);
    _dataCache[url] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

class CoverImage extends StatelessWidget {
  const CoverImage(this.url, {super.key, this.size, this.radius = T.rMd, this.circle = false});
  final String url;
  final double? size;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    const ph = ColoredBox(
      color: T.accentSoft,
      child: Center(child: Icon(AppIcons.music, color: T.accent2, size: 22)),
    );
    Widget? fromData;
    if (url.startsWith('data:image')) {
      final bytes = _decodeDataUrl(url);
      fromData = bytes == null
          ? ph
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: size == null ? null : (size! * 3).round(),
              errorBuilder: (_, __, ___) => ph,
            );
    }
    final Widget img = fromData ??
        (url.isEmpty
        ? ph
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: size == null ? null : (size! * 3).round(),
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, __) => ph,
            errorWidget: (_, __, ___) => ph,
          ));
    final clipped = circle
        ? ClipOval(child: img)
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
    return SizedBox(width: size, height: size, child: clipped);
  }
}
