import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/avatar_util.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../models/playlist.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/cover_image.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/toast.dart';
import '../widgets/track_actions.dart';
import '../widgets/track_tile.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.id});
  final String id;

  Future<void> _pickCover(BuildContext context, LibraryController ctrl, String plId) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 90);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final data = await prepareCoverDataUrl(bytes);
      if (!context.mounted) return;
      if (data == null) {
        showToast(context, 'Gambar tidak bisa diproses. Coba gambar lain.');
        return;
      }
      await ctrl.setPlaylistImage(plId, data);
      if (context.mounted) showToast(context, 'Cover playlist diperbarui');
    } catch (_) {
      if (context.mounted) showToast(context, 'Gagal memilih gambar.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final p = lib.playlistById(id);
    final handler = ref.read(audioHandlerProvider);
    final ctrl = ref.read(libraryProvider.notifier);
    if (p == null) {
      return const DetailScaffold(title: 'Playlist', children: [
        GlassCard(
          child: Text('Playlist tidak ditemukan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
        ),
      ]);
    }
    final offline = lib.isOfflinePlaylist(p.id);
    return DetailScaffold(
      title: p.name,
      children: [
        Center(child: CoverImage(p.cover, size: 180, radius: T.rXl)),
        const SizedBox(height: 14),
        Text(p.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: T.ink)),
        const SizedBox(height: 4),
        Text('${p.songs.length}/$kPlaylistMax lagu',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.ink3)),
        const SizedBox(height: 14),
        if (p.songs.isNotEmpty)
          PlayShuffleRow(
            onPlay: () => handler.playQueue(p.songs, 0),
            onShuffle: () => handler.playQueue([...p.songs]..shuffle(), 0),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Ubah nama',
                onPressed: () async {
                  final n = await showNameDialog(context, title: 'Ubah nama playlist', initial: p.name);
                  if (n != null) await ctrl.renamePlaylist(p.id, n);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(
                label: offline ? 'Hapus offline' : 'Unduh offline',
                onPressed: () async {
                  if (offline) {
                    await ctrl.removeOfflinePlaylist(p.id);
                    if (context.mounted) showToast(context, 'Unduhan playlist dihapus');
                    return;
                  }
                  if (p.songs.isEmpty) {
                    showToast(context, 'Playlist masih kosong');
                    return;
                  }
                  showToast(context, 'Mengunduh ${p.songs.length} lagu…');
                  final n = await ctrl.downloadPlaylist(p);
                  if (context.mounted) showToast(context, '$n dari ${p.songs.length} lagu tersimpan');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Ganti cover',
                onPressed: () => _pickCover(context, ctrl, p.id),
              ),
            ),
            if (p.image.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'Cover otomatis',
                  onPressed: () async {
                    await ctrl.setPlaylistImage(p.id, '');
                    if (context.mounted) showToast(context, 'Cover dikembalikan otomatis');
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Hapus playlist',
          danger: true,
          onPressed: () async {
            final ok = await showConfirm(context,
                title: 'Hapus playlist?', message: '“${p.name}” akan dihapus dari akunmu.');
            if (!ok) return;
            await ctrl.deletePlaylist(p.id);
            if (context.mounted) Navigator.of(context).maybePop();
          },
        ),
        const SizedBox(height: 16),
        if (p.songs.isEmpty)
          const GlassCard(
            child: Column(
              children: [
                Icon(AppIcons.playlist, size: 32, color: T.accent2),
                SizedBox(height: 10),
                Text('Belum ada lagu. Simpan lagu dari pemutar atau menu titik tiga.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
              ],
            ),
          ),
        for (var i = 0; i < p.songs.length; i++)
          TrackTile(
            track: p.songs[i],
            onTap: () => handler.playQueue(p.songs, i),
            onRemove: () => ctrl.removeFromPlaylist(p.id, p.songs[i].videoId),
          ),
      ],
    );
  }
}
