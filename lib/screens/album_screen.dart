import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/share_links.dart';
import '../core/theme/tokens.dart';
import '../models/playlist.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/cover_image.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/toast.dart';
import '../widgets/track_tile.dart';

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(albumProvider(id));
    final handler = ref.read(audioHandlerProvider);
    return DetailScaffold(
      title: res.valueOrNull?.title ?? 'Album',
      onShare: res.valueOrNull == null ? null : () => shareAlbum(id, res.valueOrNull!.title),
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
                SecondaryButton(label: 'Coba lagi', onPressed: () => ref.invalidate(albumProvider(id))),
              ],
            ),
          ),
        ],
        data: (a) => [
          Center(child: CoverImage(a.cover.isNotEmpty ? a.cover : (a.songs.isNotEmpty ? a.songs.first.cover : ''), size: 180, radius: T.rXl)),
          const SizedBox(height: 14),
          Text(a.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: T.ink)),
          const SizedBox(height: 4),
          Text('${a.songs.length} lagu',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.ink3)),
          const SizedBox(height: 14),
          if (a.songs.isNotEmpty)
            PlayShuffleRow(
              onPlay: () => handler.playQueue(a.songs, 0),
              onShuffle: () => handler.playQueue([...a.songs]..shuffle(), 0),
            ),
          if (a.songs.isNotEmpty) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Simpan sebagai playlist',
              onPressed: () async {
                final r = await ref
                    .read(libraryProvider.notifier)
                    .createPlaylistFromSongs(a.title, a.cover, a.songs);
                if (!context.mounted) return;
                showToast(
                    context,
                    r.dropped > 0
                        ? 'Playlist “${a.title}” tersimpan ($kPlaylistMax lagu pertama, batas playlist)'
                        : 'Playlist “${a.title}” tersimpan di Koleksi');
              },
            ),
          ],
          const SizedBox(height: 16),
          for (var i = 0; i < a.songs.length; i++)
            TrackTile(track: a.songs[i], onTap: () => handler.playQueue(a.songs, i)),
          if (a.songs.isEmpty)
            const GlassCard(
              child: Text('Daftar lagu kosong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
            ),
        ],
      ),
    );
  }
}
