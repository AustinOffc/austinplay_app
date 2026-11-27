import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/tokens.dart';
import '../models/track.dart';
import '../providers/music_providers.dart';
import '../widgets/app_background.dart';
import '../widgets/toast.dart';

/// Tautan /play/<videoId>[?title=&artist=&cover=] — memutar lagu lalu kembali ke app.
class PlayLinkScreen extends ConsumerStatefulWidget {
  const PlayLinkScreen({super.key, required this.id, this.title, this.artist, this.cover});
  final String id;
  final String? title;
  final String? artist;
  final String? cover;

  @override
  ConsumerState<PlayLinkScreen> createState() => _PlayLinkScreenState();
}

class _PlayLinkScreenState extends ConsumerState<PlayLinkScreen> {
  static final RegExp _validId = RegExp(r'^[A-Za-z0-9_-]{6,20}$');

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<Track?> _resolve() async {
    final id = widget.id;
    if (!_validId.hasMatch(id)) return null;
    final title = (widget.title ?? '').trim();
    if (title.isNotEmpty) {
      return Track(
        videoId: id,
        title: title,
        artist: (widget.artist ?? '').trim(),
        cover: coverFor(widget.cover, id),
      );
    }
    try {
      final r = await ref.read(musicServiceProvider).search('https://youtube.com/watch?v=$id', type: 'songs');
      if (r.songs.isNotEmpty) return r.songs.first;
    } catch (_) {}
    return Track(videoId: id, title: 'Lagu', artist: '', cover: coverFor(null, id));
  }

  Future<void> _open() async {
    final router = GoRouter.of(context);
    final handler = ref.read(audioHandlerProvider);
    final t = await _resolve();
    if (!mounted) return;
    if (t == null) {
      showToast(context, 'Tautan lagu tidak valid.');
    } else {
      // Pemutaran bisa lama (server menyiapkan audio); jangan tahan layar ini.
      unawaited(handler.playQueue([t], 0));
    }
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: T.accent),
              ),
              SizedBox(height: 14),
              Text('Membuka lagu…',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}
