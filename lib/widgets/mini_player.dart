import 'dart:ui' show ImageFilter;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../providers/music_providers.dart';
import '../screens/full_player.dart';
import 'cover_image.dart';

/// Mini player melayang di atas nav. Tombol play bulat dengan cincin progres.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemProvider).valueOrNull;
    if (item == null) return const SizedBox.shrink();
    final ps = ref.watch(playbackStateProvider).valueOrNull;
    final playing = ps?.playing ?? false;
    final loading = ps?.processingState == AudioProcessingState.loading;
    final handler = ref.read(audioHandlerProvider);
    final cover = (item.extras?['cover'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: T.shadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showFullPlayer(context),
              child: Container(
                height: 64,
                padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                decoration: BoxDecoration(
                  color: T.glass2,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: T.glassEdge),
                ),
                child: Row(
                  children: [
                    CoverImage(cover, size: 44, radius: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700, color: T.ink)),
                          const SizedBox(height: 1),
                          Text(item.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RingPlay(
                      duration: item.duration,
                      playing: playing,
                      loading: loading,
                      onTap: () => playing ? handler.pause() : handler.play(),
                    ),
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: handler.skipToNext,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(AppIcons.next, size: 26, color: T.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPlay extends StatelessWidget {
  const _RingPlay({
    required this.duration,
    required this.playing,
    required this.loading,
    required this.onTap,
  });
  final Duration? duration;
  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            StreamBuilder<Duration>(
              stream: AudioService.position,
              initialData: Duration.zero,
              builder: (_, snap) {
                final total = duration?.inMilliseconds ?? 0;
                final v = total <= 0 ? 0.0 : ((snap.data ?? Duration.zero).inMilliseconds / total);
                return SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    value: v.clamp(0.0, 1.0).toDouble(),
                    strokeWidth: 2.5,
                    color: T.accent,
                    backgroundColor: T.accentTint,
                  ),
                );
              },
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(playing ? AppIcons.pause : AppIcons.play, size: 22, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
