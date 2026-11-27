import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../providers/music_providers.dart';
import 'toast.dart';

/// Mulai radio dari lagu [seed] atau dari nama [artist].
Future<void> startRadio(
  ProviderContainer c,
  BuildContext tc, {
  Track? seed,
  String artist = '',
}) async {
  final handler = c.read(audioHandlerProvider);
  if (handler.locked.value) {
    showToast(tc, 'Kamu tamu di Room — hanya host yang bisa mengatur pemutaran.');
    return;
  }
  final a = artist.isNotEmpty ? artist : (seed?.artist ?? '');
  final title = seed?.title ?? '';
  if (a.isEmpty && title.isEmpty) {
    showToast(tc, 'Putar lagu dulu');
    return;
  }
  showToast(tc, 'Membuat radio…');
  final list = await c.read(musicServiceProvider).radio(title: title, artist: a, excludeId: seed?.videoId);
  if (list.isEmpty) {
    if (tc.mounted) showToast(tc, 'Radio gagal dibuat, coba lagi');
    return;
  }
  await handler.setRadio(seed, list);
  if (tc.mounted) showToast(tc, 'Radio dimulai: ${list.length} lagu mirip');
}
