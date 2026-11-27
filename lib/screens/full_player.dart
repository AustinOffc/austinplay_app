import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/share_links.dart';
import '../core/theme/tokens.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import '../services/audio_handler.dart';
import '../widgets/app_background.dart';
import '../widgets/chips.dart';
import '../widgets/cover_image.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/player_sheets.dart';
import '../widgets/track_actions.dart';

void showFullPlayer(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const FullPlayerScreen(),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: T.ease)),
      child: child,
    ),
  ));
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Pemutar penuh (tahap ini: cover, seek, kontrol, shuffle, repeat).
/// Plus: lirik, antrean, timer tidur, simpan/like, unduh, kecepatan, equalizer.
class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerState();
}

class _FullPlayerState extends ConsumerState<FullPlayerScreen> {
  bool _lyrics = false;

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(mediaItemProvider).valueOrNull;
    final ps = ref.watch(playbackStateProvider).valueOrNull;
    final handler = ref.read(audioHandlerProvider);
    final playing = ps?.playing ?? false;
    final loading = ps?.processingState == AudioProcessingState.loading;
    final size = MediaQuery.sizeOf(context);
    final coverSize = math.min(size.width - 56, 360.0);
    final cover = (item?.extras?['cover'] as String?) ?? '';

    return Scaffold(
      body: AppBackground(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).maybePop();
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GlassIconButton(icon: AppIcons.down, onTap: () => Navigator.of(context).maybePop()),
                      const Expanded(
                        child: Center(
                          child: Text('Sedang diputar',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink2)),
                        ),
                      ),
                      GlassIconButton(
                        icon: _lyrics ? AppIcons.lyricsOn : AppIcons.lyrics,
                        onTap: () => setState(() => _lyrics = !_lyrics),
                      ),
                    ],
                  ),
                  if (_lyrics && item != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: LyricsView(
                          key: ValueKey(item.id),
                          videoId: item.id,
                          title: item.title,
                          artist: item.artist ?? '',
                          cover: cover,
                          onSeek: handler.seek,
                        ),
                      ),
                    )
                  else ...[
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(T.rXl),
                        boxShadow: T.shadow,
                      ),
                      child: CoverImage(cover, size: coverSize, radius: T.rXl),
                    ),
                    const SizedBox(height: 28),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item?.title ?? 'Belum ada lagu',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: T.ink)),
                            const SizedBox(height: 4),
                            Text(item?.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: T.ink3)),
                          ],
                        ),
                      ),
                      if (item != null) _LikeButton(videoId: item.id),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SeekBar(duration: item?.duration, onSeek: handler.seek),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: handler.shuffle,
                        builder: (_, on, __) => _CtlButton(
                          icon: AppIcons.shuffle,
                          active: on,
                          onTap: handler.toggleShuffle,
                        ),
                      ),
                      _CtlButton(icon: AppIcons.prev, size: 36, onTap: handler.skipToPrevious),
                      GestureDetector(
                        onTap: () => playing ? handler.pause() : handler.play(),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
                          child: loading
                              ? const Padding(
                                  padding: EdgeInsets.all(22),
                                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                                )
                              : Icon(playing ? AppIcons.pause : AppIcons.play,
                                  size: 40, color: Colors.white),
                        ),
                      ),
                      _CtlButton(icon: AppIcons.next, size: 36, onTap: handler.skipToNext),
                      ValueListenableBuilder<RepeatMode>(
                        valueListenable: handler.repeat,
                        builder: (_, mode, __) => _CtlButton(
                          icon: mode == RepeatMode.one ? AppIcons.repeatOne : AppIcons.repeat,
                          active: mode != RepeatMode.off,
                          onTap: handler.cycleRepeat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (item != null) _ActionRow(videoId: item.id),
                  if (!(_lyrics && item != null)) const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtlButton extends StatelessWidget {
  const _CtlButton({required this.icon, required this.onTap, this.active = false, this.size = 26});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: active ? T.accent2 : T.ink2),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.duration, required this.onSeek});
  final Duration? duration;
  final Future<void> Function(Duration) onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration?.inMilliseconds ?? 0;
    final max = total > 0 ? total.toDouble() : 1.0;
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      initialData: Duration.zero,
      builder: (_, snap) {
        final pos = snap.data ?? Duration.zero;
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max).toDouble();
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: T.accent,
                inactiveTrackColor: T.accentTint,
                thumbColor: T.accent,
                overlayColor: Colors.transparent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: max,
                onChanged: total > 0 ? (v) => setState(() => _drag = v) : null,
                onChangeEnd: (v) async {
                  await widget.onSeek(Duration(milliseconds: v.round()));
                  if (mounted) setState(() => _drag = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(Duration(milliseconds: value.round())),
                      style: const TextStyle(fontSize: 11.5, color: T.ink3, fontWeight: FontWeight.w600)),
                  Text(total > 0 ? _fmt(widget.duration!) : '--:--',
                      style: const TextStyle(fontSize: 11.5, color: T.ink3, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


class _LikeButton extends ConsumerWidget {
  const _LikeButton({required this.videoId});
  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(isLikedProvider(videoId));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final t = ref.read(audioHandlerProvider).currentTrack;
        if (t == null) return;
        TrackActions.like(ProviderScope.containerOf(context), context, t);
      },
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(liked ? AppIcons.heartFill : AppIcons.heart,
            size: 26, color: liked ? T.accent2 : T.ink3),
      ),
    );
  }
}

class _ActionRow extends ConsumerStatefulWidget {
  const _ActionRow({required this.videoId});
  final String videoId;

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow> {
  // Tombol aksi disembunyikan secara default; dibuka lewat tombol titik tiga.
  bool _open = false;

  String get videoId => widget.videoId;

  @override
  Widget build(BuildContext context) {
    final ds = ref.read(downloadServiceProvider);
    ref.watch(downloadVersionProvider);
    final saved = ref.watch(libraryProvider.select((l) => l.playlists.any((p) => p.songs.any((s) => s.videoId == videoId))));
    final rate = ref.watch(settingsProvider.select((s) => s.rate));
    final has = ds.has(videoId);

    Widget btn(Widget icon, String label, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 26, width: 26, child: Center(child: icon)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: T.ink3)),
              ],
            ),
          ),
        );

    final handler = ref.read(audioHandlerProvider);
    final top = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(const Icon(AppIcons.queue, size: 24, color: T.ink2), 'Antrean', () => showQueueSheet(context)),
        ValueListenableBuilder<SleepState>(
          valueListenable: handler.sleep,
          builder: (_, sl, __) => btn(
            Icon(sl.active ? AppIcons.sleepOn : AppIcons.sleep,
                size: 24, color: sl.active ? T.accent2 : T.ink2),
            sl.endOfTrack
                ? 'Akhir lagu'
                : (sl.remaining != null ? fmtSleep(sl.remaining!) : 'Timer'),
            () => showSleepSheet(context),
          ),
        ),
        btn(const Icon(AppIcons.equalizer, size: 24, color: T.ink2), 'Equalizer', () => showEqSheet(context)),
        btn(const Icon(AppIcons.share, size: 24, color: T.ink2), 'Bagikan', () {
          final t = ref.read(audioHandlerProvider).currentTrack;
          if (t != null) shareTrack(t);
        }),
      ],
    );
    final bottom = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(Icon(saved ? AppIcons.bookmarkFill : AppIcons.bookmark, size: 24, color: saved ? T.accent2 : T.ink2),
            'Simpan', () {
          final t = ref.read(audioHandlerProvider).currentTrack;
          if (t != null) showSaveSheet(context, t);
        }),
        ValueListenableBuilder<Set<String>>(
          valueListenable: ds.paused,
          builder: (_, pausedSet, __) => ValueListenableBuilder<Map<String, double>>(
          valueListenable: ds.progress,
          builder: (_, m, __) {
            final isPaused = pausedSet.contains(videoId);
            final p = m[videoId];
            final Widget icon = p != null
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        value: p <= 0 ? null : p,
                        strokeWidth: 2.5,
                        color: T.accent,
                        backgroundColor: T.accentTint),
                  )
                : Icon(has ? AppIcons.downloadDone : AppIcons.download,
                    size: 24, color: (has || isPaused) ? T.accent2 : T.ink2);
            return btn(icon, has ? 'Offline' : (p != null ? 'Jeda' : (isPaused ? 'Lanjut' : 'Unduh')), () {
              final t = ref.read(audioHandlerProvider).currentTrack;
              if (t != null) TrackActions.download(ProviderScope.containerOf(context), context, t);
            });
          },
        )),
        btn(const Icon(AppIcons.speed, size: 24, color: T.ink2), '${_rateLabel(rate)}x',
            () => _showSpeedSheet(context)),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: T.ease,
          alignment: Alignment.bottomCenter,
          child: _open
              ? Column(mainAxisSize: MainAxisSize.min, children: [top, bottom])
              : const SizedBox(width: double.infinity),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: _open ? 'Sembunyikan' : 'Opsi lainnya',
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(AppIcons.more, size: 26, color: _open ? T.accent2 : T.ink2),
          ),
        ),
      ],
    );
  }
}

String _rateLabel(double r) {
  final s = r.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

const List<double> _rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

void _showSpeedSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: T.scrim,
    builder: (_) => const _SpeedSheet(),
  );
}

class _SpeedSheet extends ConsumerWidget {
  const _SpeedSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(settingsProvider.select((s) => s.rate));
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(255, 246, 249, .96),
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
        border: Border(top: BorderSide(color: T.glassEdge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: T.ink4, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Kecepatan putar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _rates)
                AppChip(
                  label: '${_rateLabel(r)}x',
                  active: (rate - r).abs() < 0.01,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setRate(r);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
