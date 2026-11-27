import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../models/browse.dart';
import '../models/track.dart';
import '../providers/music_providers.dart';
import 'cover_image.dart';
import 'glass_card.dart';
import 'track_actions.dart';

/// Baris lagu (tanpa blur supaya list panjang tetap ringan).
class TrackTile extends ConsumerWidget {
  const TrackTile({super.key, required this.track, required this.onTap, this.onRemove});
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCur = ref.watch(currentVideoIdProvider) == track.videoId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        shadow: false,
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Row(
          children: [
            CoverImage(track.cover, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isCur ? T.accent2 : T.ink)),
                  const SizedBox(height: 2),
                  Text(track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (track.durationLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(track.durationLabel,
                  style: const TextStyle(fontSize: 11.5, color: T.ink3, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove ?? () => showTrackMenu(context, track),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                    onRemove != null ? AppIcons.trash : (isCur ? AppIcons.music : AppIcons.more),
                    size: 22,
                    color: onRemove != null ? T.danger : T.accent2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris playlist / album / artis.
class BrowseRow extends StatelessWidget {
  const BrowseRow({super.key, required this.item, required this.onTap});
  final BrowseItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        shadow: false,
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: Row(
          children: [
            CoverImage(item.cover, size: 52, circle: item.kind == BrowseKind.artist),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            const Icon(AppIcons.chevronRight, size: 22, color: T.ink4),
          ],
        ),
      ),
    );
  }
}

/// Kartu persegi untuk grid "Pilihan untukmu".
class SongCard extends ConsumerWidget {
  const SongCard({super.key, required this.track, required this.onTap});
  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCur = ref.watch(currentVideoIdProvider) == track.videoId;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (_, c) => CoverImage(track.cover, size: c.maxWidth),
            ),
          ),
          const SizedBox(height: 8),
          Text(track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: isCur ? T.accent2 : T.ink)),
          const SizedBox(height: 1),
          Text(track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
