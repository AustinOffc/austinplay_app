import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/icons.dart';
import '../core/layout.dart';
import '../core/theme/tokens.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass_card.dart';
import '../widgets/page_header.dart';
import '../widgets/toast.dart';
import '../widgets/track_actions.dart';
import '../widgets/track_tile.dart';

const List<String> _tabs = ['Playlists', 'Artists', 'Offline', 'Favorit'];

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<bool>>(onlineProvider, (prev, next) {
      final online = next.valueOrNull;
      if (online == false && prev?.valueOrNull != false && mounted) {
        setState(() => _tab = 2);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final hasPlayer = ref.watch(hasPlayerProvider);
    final pad = contentBottomPad(context, withPlayer: hasPlayer);
    return Column(
      children: [
        const PageHeader(title: 'Koleksi'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _Segmented(index: _tab, onChanged: (i) => setState(() => _tab = i)),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _PlaylistsTab(bottomPad: pad),
              _ArtistsTab(bottomPad: pad),
              _OfflineTab(bottomPad: pad),
              _LikedTab(bottomPad: pad),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: T.glass,
        borderRadius: BorderRadius.circular(T.rPill),
        border: Border.all(color: T.glassEdge),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: T.dur,
                  curve: T.ease,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? T.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(T.rPill),
                  ),
                  child: Text(_tabs[i],
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                          color: i == index ? Colors.white : T.ink2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, size: 32, color: T.accent2),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
        ],
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist, required this.offline, required this.onTap});
  final Playlist playlist;
  final bool offline;
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
            CoverImage(playlist.cover, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
                  const SizedBox(height: 2),
                  Text('${playlist.songs.length} lagu',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3)),
                ],
              ),
            ),
            if (offline) const Icon(AppIcons.downloadDone, size: 20, color: T.accent2),
            const SizedBox(width: 4),
            const Icon(AppIcons.chevronRight, size: 22, color: T.ink4),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab({required this.bottomPad});
  final double bottomPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      children: [
        PrimaryButton(
          label: 'Playlist baru',
          onPressed: () async {
            final name = await showNameDialog(context, title: 'Playlist baru');
            if (name == null || name.trim().isEmpty) return;
            await ref.read(libraryProvider.notifier).createPlaylist(name);
          },
        ),
        const SizedBox(height: 12),
        if (lib.playlists.isEmpty)
          const _Empty(AppIcons.playlist, 'Belum ada playlist. Buat satu atau simpan lagu dari pemutar.'),
        for (final p in lib.playlists)
          _PlaylistRow(
            playlist: p,
            offline: lib.isOfflinePlaylist(p.id),
            onTap: () => context.push('/playlist/${Uri.encodeComponent(p.id)}'),
          ),
      ],
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab({required this.bottomPad});
  final double bottomPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      children: [
        if (lib.artists.isEmpty)
          const _Empty(AppIcons.artist, 'Belum ada artis favorit. Buka halaman artis lalu ketuk ikon hati.'),
        for (final a in lib.artists)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              blur: false,
              shadow: false,
              padding: const EdgeInsets.all(10),
              onTap: () => context.push('/artist/${Uri.encodeComponent(a.artistId)}'),
              child: Row(
                children: [
                  CoverImage(a.thumbnail, size: 52, circle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        ref.read(libraryProvider.notifier).toggleLikeArtist(a.artistId, a.name, a.thumbnail),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(AppIcons.heartFill, size: 22, color: T.accent2),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LikedTab extends ConsumerWidget {
  const _LikedTab({required this.bottomPad});
  final double bottomPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(libraryProvider.select((s) => s.songs));
    final handler = ref.read(audioHandlerProvider);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
      children: [
        if (songs.isEmpty)
          const _Empty(AppIcons.heart, 'Belum ada lagu favorit. Ketuk ikon hati di pemutar.')
        else ...[
          PlayShuffleRowLite(
            onPlay: () => handler.playQueue(songs, 0),
            onShuffle: () => handler.playQueue([...songs]..shuffle(), 0),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < songs.length; i++)
            TrackTile(track: songs[i], onTap: () => handler.playQueue(songs, i)),
        ],
      ],
    );
  }
}

class PlayShuffleRowLite extends StatelessWidget {
  const PlayShuffleRowLite({super.key, required this.onPlay, required this.onShuffle});
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, IconData icon, bool primary, VoidCallback f) => Expanded(
          child: GestureDetector(
            onTap: f,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: primary ? T.accent : T.glass2,
                borderRadius: BorderRadius.circular(T.rPill),
                border: primary ? null : Border.all(color: T.glassEdge),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: primary ? Colors.white : T.ink2),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary ? Colors.white : T.ink2)),
                ],
              ),
            ),
          ),
        );
    return Row(children: [
      btn('Putar semua', AppIcons.play, true, onPlay),
      const SizedBox(width: 10),
      btn('Acak', AppIcons.shuffle, false, onShuffle),
    ]);
  }
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class _OfflineTab extends ConsumerStatefulWidget {
  const _OfflineTab({required this.bottomPad});
  final double bottomPad;

  @override
  ConsumerState<_OfflineTab> createState() => _OfflineTabState();
}

class _OfflineTabState extends ConsumerState<_OfflineTab> {
  int _bytes = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    final n = await ref.read(downloadServiceProvider).totalBytes();
    if (mounted) setState(() => _bytes = n);
  }

  Future<void> _backfill() async {
    if (_busy) return;
    setState(() => _busy = true);
    final n = await ref.read(libraryProvider.notifier).backfillMissing(force: true, limit: 100);
    if (!mounted) return;
    setState(() => _busy = false);
    showToast(context, n > 0 ? '$n lagu selesai diunduh' : 'Tidak ada unduhan baru');
    _refreshSize();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(downloadVersionProvider);
    final lib = ref.watch(libraryProvider);
    final ds = ref.read(downloadServiceProvider);
    final online = ref.watch(onlineProvider).valueOrNull ?? true;
    final handler = ref.read(audioHandlerProvider);
    final entries = lib.offline;
    final ready = entries.where((e) => ds.has(e.id)).map((e) => e.track).toList();
    final missing = entries.length - ready.length;
    final queueSource = online ? entries.map((e) => e.track).toList() : ready;

    ref.listen<int>(
        downloadVersionProvider.select((v) => v.valueOrNull ?? 0), (_, __) => _refreshSize());

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPad),
      children: [
        GlassCard(
          child: Row(
            children: [
              const Icon(AppIcons.downloadDone, size: 28, color: T.accent2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${ready.length} lagu tersimpan',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
                    const SizedBox(height: 2),
                    Text(
                        missing > 0
                            ? '${formatBytes(_bytes)} • $missing belum diunduh di perangkat ini'
                            : formatBytes(_bytes),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const _Empty(AppIcons.download, 'Belum ada lagu offline. Pakai menu titik tiga atau tombol unduh di pemutar.')
        else ...[
          PlayShuffleRowLite(
            onPlay: () {
              if (queueSource.isEmpty) {
                showToast(context, 'Belum ada lagu yang bisa diputar offline');
                return;
              }
              handler.playQueue(queueSource, 0);
            },
            onShuffle: () {
              if (queueSource.isEmpty) return;
              handler.playQueue([...queueSource]..shuffle(), 0);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (missing > 0 && online)
                Expanded(
                    child: SecondaryButton(
                        label: _busy ? 'Mengunduh…' : 'Unduh yang belum ($missing)',
                        onPressed: _busy ? null : _backfill)),
              if (missing > 0 && online) const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'Hapus semua',
                  danger: true,
                  onPressed: () async {
                    final ok = await showConfirm(context,
                        title: 'Hapus semua unduhan?',
                        message: 'File audio di perangkat ini akan dihapus dan daftar offline dikosongkan.');
                    if (!ok) return;
                    await ref.read(libraryProvider.notifier).clearOffline();
                    _refreshSize();
                  },
                ),
              ),
            ],
          ),
        ],
        if (lib.offlinePlaylists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 18, 0, 10),
            child: Text('Playlist offline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
          ),
          for (final op in lib.offlinePlaylists)
            if (lib.playlistById(op.id) != null)
              _PlaylistRow(
                playlist: lib.playlistById(op.id)!,
                offline: true,
                onTap: () => context.push('/playlist/${Uri.encodeComponent(op.id)}'),
              ),
        ],
        if (entries.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 18, 0, 10),
            child: Text('Lagu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
          ),
          for (final e in entries) _OfflineTile(entry: e, queue: queueSource, online: online),
        ],
      ],
    );
  }
}

class _OfflineTile extends ConsumerWidget {
  const _OfflineTile({required this.entry, required this.queue, required this.online});
  final OfflineEntry entry;
  final List<Track> queue;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.read(downloadServiceProvider);
    final handler = ref.read(audioHandlerProvider);
    final t = entry.track;
    final has = ds.has(t.videoId);
    final isCur = ref.watch(currentVideoIdProvider) == t.videoId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        blur: false,
        shadow: false,
        padding: const EdgeInsets.all(10),
        onTap: () {
          if (!has && !online) {
            showToast(context, 'Lagu ini belum diunduh di perangkat ini');
            return;
          }
          final i = queue.indexWhere((q) => q.videoId == t.videoId);
          if (i >= 0) {
            handler.playQueue(queue, i);
          } else {
            handler.playQueue([t], 0);
          }
        },
        child: Row(
          children: [
            CoverImage(t.cover, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: isCur ? T.accent2 : T.ink)),
                  const SizedBox(height: 2),
                  Text(t.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            ValueListenableBuilder<Set<String>>(
              valueListenable: ds.paused,
              builder: (_, pausedSet, __) => ValueListenableBuilder<Map<String, double>>(
              valueListenable: ds.progress,
              builder: (_, m, __) {
                final p = m[t.videoId];
                if (p == null && pausedSet.contains(t.videoId)) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => TrackActions.download(ProviderScope.containerOf(context), context, t),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(AppIcons.play, size: 22, color: T.accent2),
                    ),
                  );
                }
                if (p != null) {
                  return GestureDetector(
                    onTap: () => ds.pause(t.videoId),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                              value: p <= 0 ? null : p,
                              strokeWidth: 2.5,
                              color: T.accent,
                              backgroundColor: T.accentTint),
                          const Icon(AppIcons.pause, size: 14, color: T.accent2),
                        ],
                      ),
                    ),
                  );
                }
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: has
                        ? null
                        : () => TrackActions.download(ProviderScope.containerOf(context), context, t),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(has ? AppIcons.downloadDone : AppIcons.download,
                          size: 22, color: has ? T.accent2 : T.ink4),
                    ),
                  );
              },
            )),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await ref.read(libraryProvider.notifier).removeOffline(t.videoId);
              },
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(AppIcons.trash, size: 22, color: T.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
