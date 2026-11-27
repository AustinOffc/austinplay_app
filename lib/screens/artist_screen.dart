import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/share_links.dart';
import '../core/theme/tokens.dart';
import '../models/browse.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import '../core/icons.dart';
import '../widgets/toast.dart';
import '../widgets/browse_actions.dart';
import '../widgets/buttons.dart';
import '../widgets/cover_image.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/track_tile.dart';

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(artistProvider(id));
    final handler = ref.read(audioHandlerProvider);

    Widget section(String title, List<BrowseItem> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 0, 10),
              child: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
            ),
            for (final it in items.take(10))
              BrowseRow(item: it, onTap: () => openBrowseItem(context, ref, it)),
          ],
        );

    return DetailScaffold(
      title: res.valueOrNull?.name ?? 'Artis',
      onShare: res.valueOrNull == null ? null : () => shareArtist(id, res.valueOrNull!.name),
      children: res.when(
        loading: () => [
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(color: T.accent, strokeWidth: 3)),
          ),
        ],
        error: (e, _) => [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(ApiClient.messageOf(e),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
                const SizedBox(height: 12),
                SecondaryButton(label: 'Coba lagi', onPressed: () => ref.invalidate(artistProvider(id))),
              ],
            ),
          ),
        ],
        data: (a) => [
          Center(child: CoverImage(a.cover, size: 130, circle: true)),
          const SizedBox(height: 14),
          Text(a.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: T.ink)),
          const SizedBox(height: 10),
          Center(child: _ArtistLike(id: id, name: a.name, cover: a.cover)),
          const SizedBox(height: 14),
          if (a.topSongs.isNotEmpty) ...[
            PlayShuffleRow(
              onPlay: () => handler.playQueue(a.topSongs, 0),
              onShuffle: () => handler.playQueue([...a.topSongs]..shuffle(), 0),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(2, 16, 0, 10),
              child: Text('Lagu populer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
            ),
            for (var i = 0; i < a.topSongs.length; i++)
              TrackTile(track: a.topSongs[i], onTap: () => handler.playQueue(a.topSongs, i)),
          ],
          if (a.albums.isNotEmpty) section('Album', a.albums),
          if (a.singles.isNotEmpty) section('Single & EP', a.singles),
          if (a.playlists.isNotEmpty) section('Playlist', a.playlists),
          if (a.similar.isNotEmpty) section('Artis mirip', a.similar),
        ],
      ),
    );
  }
}


class _ArtistLike extends ConsumerWidget {
  const _ArtistLike({required this.id, required this.name, required this.cover});
  final String id;
  final String name;
  final String cover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(libraryProvider.select((s) => s.isArtistLiked(id)));
    return GestureDetector(
      onTap: () async {
        final on = await ref.read(libraryProvider.notifier).toggleLikeArtist(id, name, cover);
        if (context.mounted) {
          showToast(context, on ? 'Ditambahkan ke Artist Disukai' : 'Dihapus dari Artist Disukai');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: liked ? T.accent : T.glass2,
          borderRadius: BorderRadius.circular(T.rPill),
          border: liked ? null : Border.all(color: T.glassEdge),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(liked ? AppIcons.heartFill : AppIcons.heart,
                size: 18, color: liked ? Colors.white : T.ink2),
            const SizedBox(width: 6),
            Text(liked ? 'Disukai' : 'Sukai artis',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: liked ? Colors.white : T.ink2)),
          ],
        ),
      ),
    );
  }
}
