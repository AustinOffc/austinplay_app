import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import 'cover_image.dart';
import 'radio_action.dart';
import 'toast.dart';

class TrackActions {
  static Future<void> like(ProviderContainer c, BuildContext tc, Track t) async {
    final on = await c.read(libraryProvider.notifier).toggleLike(t);
    if (tc.mounted) showToast(tc, on ? 'Ditambahkan ke Favorit' : 'Dihapus dari Favorit');
  }

  static Future<void> download(ProviderContainer c, BuildContext tc, Track t) async {
    final ds = c.read(downloadServiceProvider);
    if (ds.has(t.videoId)) {
      await c.read(libraryProvider.notifier).removeOffline(t.videoId);
      if (tc.mounted) showToast(tc, 'Unduhan dihapus');
      return;
    }
    if (ds.isBusy(t.videoId)) {
      ds.pause(t.videoId);
      if (tc.mounted) showToast(tc, 'Unduhan dijeda. Ketuk lagi untuk melanjutkan.');
      return;
    }
    if (tc.mounted) {
      showToast(tc, ds.isPaused(t.videoId) ? 'Melanjutkan unduhan…' : 'Mengunduh “${t.title}”…');
    }
    final ok = await c.read(libraryProvider.notifier).downloadTrack(t);
    if (!tc.mounted) return;
    showToast(tc, ok ? 'Tersimpan untuk offline' : (ds.lastError.isEmpty ? 'Unduhan gagal' : ds.lastError));
  }
}

Future<String?> showNameDialog(BuildContext context, {required String title, String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    barrierColor: T.scrim,
    builder: (ctx) => AlertDialog(
      backgroundColor: T.bg1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
      title: Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        style: const TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Nama playlist',
          counterText: '',
          filled: true,
          fillColor: Colors.white.withValues(alpha: .78),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.accent)),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: T.ink3, fontWeight: FontWeight.w700))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Simpan', style: TextStyle(color: T.accent2, fontWeight: FontWeight.w800))),
      ],
    ),
  );
}

Future<bool> showConfirm(BuildContext context,
    {required String title, required String message, String action = 'Hapus'}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: T.scrim,
    builder: (ctx) => AlertDialog(
      backgroundColor: T.bg1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
      title: Text(title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
      content: Text(message,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: T.ink2)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: T.ink3, fontWeight: FontWeight.w700))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: T.danger, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return r == true;
}

Future<void> _sheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: T.scrim,
    builder: builder,
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.75;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rXl)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxH),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
          decoration: const BoxDecoration(
            color: Color.fromRGBO(255, 246, 249, .94),
            border: Border(top: BorderSide(color: T.glassEdge)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: T.ink4, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showSaveSheet(BuildContext context, Track track) =>
    _sheet(context, (_) => _SaveSheet(track: track));

class _SaveSheet extends ConsumerWidget {
  const _SaveSheet({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final ctrl = ref.read(libraryProvider.notifier);
    final toastCtx = Navigator.of(context, rootNavigator: true).context;
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Simpan ke…',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in lib.playlists)
                  _PlaylistPickRow(
                    playlist: p,
                    has: p.songs.any((s) => s.videoId == track.videoId),
                    onTap: () async {
                      final has = p.songs.any((s) => s.videoId == track.videoId);
                      if (has) {
                        await ctrl.removeFromPlaylist(p.id, track.videoId);
                        if (toastCtx.mounted) showToast(toastCtx, 'Dihapus dari ${p.name}');
                        return;
                      }
                      final r = await ctrl.addToPlaylist(p.id, track);
                      if (!toastCtx.mounted) return;
                      showToast(
                          toastCtx,
                          r == AddResult.full
                              ? 'Playlist penuh (maks $kPlaylistMax lagu)'
                              : 'Ditambahkan ke ${p.name}');
                    },
                  ),
                if (lib.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('Belum ada playlist.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink3)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final name = await showNameDialog(context, title: 'Playlist baru');
              if (name == null || name.trim().isEmpty) return;
              final p = await ctrl.createPlaylist(name, first: track);
              if (toastCtx.mounted) showToast(toastCtx, 'Disimpan ke ${p.name}');
            },
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: T.accent,
                borderRadius: BorderRadius.circular(T.rPill),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.add, size: 20, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Playlist baru',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistPickRow extends StatelessWidget {
  const _PlaylistPickRow({required this.playlist, required this.has, required this.onTap});
  final Playlist playlist;
  final bool has;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CoverImage(playlist.cover, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
                  Text('${playlist.songs.length} lagu',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3)),
                ],
              ),
            ),
            Icon(has ? AppIcons.bookmarkFill : AppIcons.bookmark,
                size: 24, color: has ? T.accent2 : T.ink4),
          ],
        ),
      ),
    );
  }
}

Future<void> showTrackMenu(BuildContext context, Track track) =>
    _sheet(context, (_) => _TrackMenu(track: track));

class _TrackMenu extends ConsumerWidget {
  const _TrackMenu({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(isLikedProvider(track.videoId));
    ref.watch(downloadVersionProvider);
    final ds = ref.read(downloadServiceProvider);
    final has = ds.has(track.videoId);
    final container = ProviderScope.containerOf(context);
    final nav = Navigator.of(context, rootNavigator: true);
    final router = GoRouter.of(context);

    Widget item(IconData icon, String label, VoidCallback onTap, {Color color = T.ink}) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color == T.ink ? T.accent2 : color),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        );

    return _SheetFrame(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CoverImage(track.cover, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
                      Text(track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: T.ink3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            item(liked ? AppIcons.heartFill : AppIcons.heart, liked ? 'Hapus dari Favorit' : 'Tambah ke Favorit',
                () {
              Navigator.pop(context);
              TrackActions.like(container, nav.context, track);
            }),
            item(AppIcons.playNext, 'Putar berikutnya', () {
              Navigator.pop(context);
              container.read(audioHandlerProvider).addNext(track);
              showToast(nav.context, 'Diputar setelah lagu ini');
            }),
            item(AppIcons.addQueue, 'Tambah ke antrean', () {
              Navigator.pop(context);
              container.read(audioHandlerProvider).addToEnd(track);
              showToast(nav.context, 'Ditambahkan ke antrean');
            }),
            item(AppIcons.radio, 'Mulai radio', () {
              Navigator.pop(context);
              startRadio(container, nav.context, seed: track);
            }),
            item(AppIcons.bookmark, 'Simpan ke playlist', () {
              Navigator.pop(context);
              showSaveSheet(nav.context, track);
            }),
            item(has ? AppIcons.trash : AppIcons.download, has ? 'Hapus unduhan' : 'Unduh untuk offline', () {
              Navigator.pop(context);
              TrackActions.download(container, nav.context, track);
            }, color: has ? T.danger : T.ink),
            if (track.artistId.isNotEmpty)
              item(AppIcons.artist, 'Ke halaman artis', () {
                Navigator.pop(context);
                router.push('/artist/${Uri.encodeComponent(track.artistId)}');
              }),
            if (track.albumId.isNotEmpty)
              item(AppIcons.album, 'Ke album', () {
                Navigator.pop(context);
                router.push('/album/${Uri.encodeComponent(track.albumId)}');
              }),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet kaca generik (dipakai Room & Profil).
Future<void> showGlassSheet(BuildContext context, Widget child) =>
    _sheet(context, (_) => _SheetFrame(child: child));

/// Satu baris menu di dalam sheet (ikon + label).
class SheetItem extends StatelessWidget {
  const SheetItem({super.key, required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? T.danger : T.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: danger ? T.danger : T.accent2),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
