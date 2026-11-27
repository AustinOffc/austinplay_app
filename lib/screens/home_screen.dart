import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/icons.dart';
import '../core/layout.dart';
import '../core/theme/tokens.dart';
import '../models/browse.dart';
import '../models/track.dart';
import '../providers/discover_providers.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import '../widgets/browse_actions.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass_card.dart';
import '../widgets/radio_action.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _active = 'Semua';
  bool _more = false;

  void _select(String name) {
    setState(() => _active = (_active == name && name != 'Semua') ? 'Semua' : name);
  }

  Future<void> _refresh() async {
    ref.invalidate(homeDataProvider);
    ref.invalidate(popularArtistsProvider);
    if (_active != 'Semua') ref.invalidate(categoryResultProvider(_active));
    try {
      await ref.read(homeDataProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasPlayer = ref.watch(hasPlayerProvider);
    final top = MediaQuery.paddingOf(context).top;
    final primary = kCategories.take(4).toList();
    final rest = kCategories.skip(4).toList();
    return RefreshIndicator(
      color: T.accent,
      backgroundColor: Colors.white,
      edgeOffset: top,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, top + 12, 16, contentBottomPad(context, withPlayer: hasPlayer)),
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/auzify-icon-512.png', width: 36, height: 36),
              ),
              const SizedBox(width: 10),
              const Expanded(child: _BrandName()),
              GlassIconButton(icon: AppIcons.search, onTap: () => context.go('/search')),
              const SizedBox(width: 8),
              GlassIconButton(icon: AppIcons.profile, onTap: () => context.go('/profile')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in primary)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChip(label: c, active: _active == c, onTap: () => _select(c)),
                        ),
                    ],
                  ),
                ),
              ),
              GlassIconButton(
                size: 36,
                icon: _more ? AppIcons.close : AppIcons.down,
                onTap: () => setState(() => _more = !_more),
              ),
            ],
          ),
          AnimatedSize(
            duration: T.dur,
            curve: T.ease,
            alignment: Alignment.topCenter,
            child: _more
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in rest)
                            AppChip(label: c, active: _active == c, onTap: () => _select(c)),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          if (_active == 'Semua')
            const _DefaultSections()
          else
            _CategorySections(key: ValueKey(_active), name: _active),
        ],
      ),
    );
  }
}

/// Nama brand bergantian (Auzify → Austin → Emza Luciana) dengan animasi huruf-per-huruf
/// seperti web (`.bn-*`): masuk naik+blur-hilang / flip / pop bergantian, lalu bergoyang halus
/// 1.5px, keluar naik+blur+pudar. Tanpa glow. Hormati reduce-motion.
class _BrandName extends StatefulWidget {
  const _BrandName();
  @override
  State<_BrandName> createState() => _BrandNameState();
}

class _BrandNameState extends State<_BrandName> with TickerProviderStateMixin {
  static const _words = ['Auzify', 'Austin', 'Emza Luciana'];
  static const double _fs = 19;
  static const Curve _pop = Cubic(.34, 1.4, .5, 1);

  late final AnimationController _ctl = AnimationController(vsync: this);
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  int _i = 0;
  bool _out = false;
  int _totalMs = 1000;
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    _loop();
  }

  Future<void> _loop() async {
    while (_alive) {
      final n = _words[_i].length;
      _out = false;
      _totalMs = 700 + 55 * n;
      _ctl.duration = Duration(milliseconds: _totalMs);
      _float.repeat();
      _ctl.forward(from: 0);
      await Future<void>.delayed(Duration(milliseconds: _totalMs + 1500));
      if (!_alive) return;
      _out = true;
      _totalMs = 400 + 28 * n;
      _ctl.duration = Duration(milliseconds: _totalMs);
      _ctl.forward(from: 0);
      await Future<void>.delayed(Duration(milliseconds: _totalMs + 80));
      if (!_alive) return;
      setState(() => _i = (_i + 1) % _words.length);
    }
  }

  @override
  void dispose() {
    _alive = false;
    _ctl.dispose();
    _float.dispose();
    super.dispose();
  }

  Widget _letter(String ch, int idx, Color color) {
    final style = TextStyle(
        fontSize: _fs, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: color, height: 1.2);
    if (ch == ' ') return const SizedBox(width: _fs * .3);
    final fx = _i % 3;
    return AnimatedBuilder(
      animation: Listenable.merge([_ctl, _float]),
      builder: (context, _) {
        final ms = _ctl.value * _totalMs;
        double opacity = 1, dy = 0, blur = 0, scale = 1, rot = 0;
        if (_out) {
          final p = ((ms - 28 * idx) / 400).clamp(0.0, 1.0).toDouble();
          final e = Curves.easeIn.transform(p);
          opacity = 1 - e;
          dy = -.6 * _fs * e;
          blur = 6 * e;
        } else {
          final p = ((ms - 55 * idx) / 700).clamp(0.0, 1.0).toDouble();
          final e = (fx == 2 ? _pop : T.ease).transform(p);
          final r = 1 - e;
          opacity = T.ease.transform(p).clamp(0.0, 1.0).toDouble();
          switch (fx) {
            case 0:
              dy = .55 * _fs * r;
              blur = 6 * r;
              break;
            case 1:
              rot = -85 * 3.14159265 / 180 * r;
              dy = .2 * _fs * r;
              blur = 4 * r;
              break;
            default:
              scale = .45 + .55 * e;
              dy = .3 * _fs * r;
              blur = 5 * r;
          }
          if (p >= 1) {
            final ph = (_float.value - idx * .0375) % 1.0;
            dy = -1.5 * (.5 - .5 * math.cos(2 * math.pi * ph));
          }
        }
        Widget w = Text(ch, style: style);
        if (rot != 0 || scale != 1) {
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.003)
            ..rotateX(rot)
            ..scale(scale, scale);
          w = Transform(alignment: Alignment.bottomCenter, transform: m, child: w);
        }
        if (blur > .3) {
          w = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: w);
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(offset: Offset(0, dy), child: w),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = _words[_i];
    final color = _i == 2 ? T.accent2 : T.ink;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(word,
            style: TextStyle(
                fontSize: _fs, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: color)),
      );
    }
    final chars = word.split('');
    return Semantics(
      label: 'Auzify',
      excludeSemantics: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: RepaintBoundary(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (var k = 0; k < chars.length; k++) _letter(chars[k], k, color)],
          ),
        ),
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 18) return 'Selamat sore';
  return 'Selamat malam';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: T.ink)),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ApiClient.messageOf(error),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
            const SizedBox(height: 12),
            SecondaryButton(label: 'Coba lagi', onPressed: onRetry),
          ],
        ),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    Widget box(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: T.accentSoft, borderRadius: BorderRadius.circular(T.rMd)),
        );
    return Column(children: [box(150), box(150), box(60), box(60)]);
  }
}

Widget _songGrid(BuildContext context, WidgetRef ref, List<Track> songs) {
  final w = MediaQuery.sizeOf(context).width;
  final handler = ref.read(audioHandlerProvider);
  final shown = songs.take(6).toList();
  return GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: w >= 640 ? 3 : 2,
    mainAxisSpacing: 14,
    crossAxisSpacing: 12,
    childAspectRatio: 0.78,
    children: [
      for (var i = 0; i < shown.length; i++)
        SongCard(track: shown[i], onTap: () => handler.playQueue(songs, i)),
    ],
  );
}

Widget _artistPills(List<BrowseItem> artists, void Function(BrowseItem) onTap) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final a in artists)
        GestureDetector(
          onTap: () => onTap(a),
          child: Container(
            padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
            decoration: BoxDecoration(
              color: T.glass,
              borderRadius: BorderRadius.circular(T.rPill),
              border: Border.all(color: T.glassEdge),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoverImage(a.cover, size: 28, circle: true),
                const SizedBox(width: 8),
                Text(a.title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.ink2)),
              ],
            ),
          ),
        ),
    ],
  );
}

class _DefaultSections extends ConsumerWidget {
  const _DefaultSections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDataProvider);
    final artists = ref.watch(popularArtistsProvider);
    final recent = ref.watch(recentTracksProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          strong: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.accent2)),
              const SizedBox(height: 4),
              const Text('Mau dengar apa hari ini?',
                  style: TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: T.ink)),
              const SizedBox(height: 6),
              const Text('Cari lagu favoritmu, simpan ke koleksi, dan ikuti liriknya langsung di pemutar.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: T.ink2)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: PrimaryButton(label: 'Cari lagu', onPressed: () => context.go('/search'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: SecondaryButton(
                          label: 'Buka koleksi', onPressed: () => context.go('/library'))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (recent.isNotEmpty) ...[
          const _SectionTitle('Terakhir diputar'),
          _songGrid(context, ref, recent),
          const SizedBox(height: 22),
        ],
        const _ChartSection(),
        const _RadioSection(),
        const _TopHitsSection(),
        home.when(
          loading: () => const _Skeleton(),
          error: (e, _) => _ErrorCard(error: e, onRetry: () => ref.invalidate(homeDataProvider)),
          data: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.songs.isNotEmpty) ...[
                const _SectionTitle('Pilihan untukmu'),
                _songGrid(context, ref, d.songs),
                const SizedBox(height: 22),
              ],
              if (artists.valueOrNull?.isNotEmpty ?? false) ...[
                const _SectionTitle('Artis populer'),
                _artistPills(artists.value!, (a) => openBrowseItem(context, ref, a)),
                const SizedBox(height: 22),
              ],
              if (d.playlists.isNotEmpty) ...[
                const _SectionTitle('Playlist & album'),
                for (final p in d.playlists.take(12))
                  BrowseRow(item: p, onTap: () => openBrowseItem(context, ref, p)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Chart: tab Indonesia / Global / Viral (hasil pencarian, di-cache 6 jam seperti web).
class _ChartSection extends ConsumerStatefulWidget {
  const _ChartSection();
  @override
  ConsumerState<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends ConsumerState<_ChartSection> {
  String _key = kCharts.first.$1;

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(chartProvider(_key));
    final handler = ref.read(audioHandlerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Chart'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kCharts)
              AppChip(label: c.$2, active: _key == c.$1, onTap: () => setState(() => _key = c.$1)),
          ],
        ),
        const SizedBox(height: 12),
        res.when(
          loading: () => const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: T.accent)),
          ),
          error: (_, __) => const Text('Chart tidak tersedia saat ini.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: T.ink3)),
          data: (list) => list.isEmpty
              ? const Text('Chart tidak tersedia saat ini.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: T.ink3))
              : SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _ChartCard(
                      rank: i + 1,
                      track: list[i],
                      onTap: () => handler.playQueue(list, i),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.rank, required this.track, required this.onTap});
  final int rank;
  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverImage(track.cover, size: 132, radius: T.rMd),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: T.accent,
                      borderRadius: BorderRadius.circular(T.rPill),
                    ),
                    child: Text('#$rank',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: T.ink)),
            Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3)),
          ],
        ),
      ),
    );
  }
}

/// Radio: antrean otomatis lagu mirip dari artis yang paling sering didengar / lagu yang sedang diputar.
class _RadioSection extends ConsumerWidget {
  const _RadioSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topArtistProvider);
    final playing = ref.watch(hasPlayerProvider);
    if (top == null && !playing) return const SizedBox.shrink();
    final container = ProviderScope.containerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Radio'),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Antrean otomatis berisi lagu-lagu yang mirip.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: T.ink2)),
              const SizedBox(height: 12),
              if (top != null)
                PrimaryButton(
                  label: 'Radio $top',
                  onPressed: () => startRadio(container, context, artist: top),
                ),
              if (top != null && playing) const SizedBox(height: 8),
              if (playing)
                SecondaryButton(
                  label: 'Radio dari lagu ini',
                  onPressed: () {
                    final t = ref.read(audioHandlerProvider).currentTrack;
                    if (t != null) startRadio(container, context, seed: t);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _TopHitsSection extends ConsumerWidget {
  const _TopHitsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(topHitsProvider).valueOrNull ?? const <Track>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final handler = ref.read(audioHandlerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Top Hits 2026')),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton(
                onPressed: () => handler.playQueue(list, 0),
                child: const Text('▶ Putar semua',
                    style: TextStyle(color: T.accent2, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        for (var i = 0; i < list.length; i++)
          TrackTile(track: list[i], onTap: () => handler.playQueue(list, i)),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _CategorySections extends ConsumerWidget {
  const _CategorySections({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(categoryResultProvider(name));
    final handler = ref.read(audioHandlerProvider);
    return res.when(
      loading: () => const _Skeleton(),
      error: (e, _) =>
          _ErrorCard(error: e, onRetry: () => ref.invalidate(categoryResultProvider(name))),
      data: (r) {
        if (r.isEmpty) {
          return const GlassCard(
            child: Text('Belum ada hasil untuk kategori ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(name),
            for (var i = 0; i < r.songs.length; i++)
              TrackTile(track: r.songs[i], onTap: () => handler.playQueue(r.songs, i)),
            if (r.playlistsAndAlbums.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _SectionTitle('Playlist & album'),
              for (final p in r.playlistsAndAlbums.take(8))
                BrowseRow(item: p, onTap: () => openBrowseItem(context, ref, p)),
            ],
            if (r.artists.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _SectionTitle('Artis terkait'),
              _artistPills(r.artists.take(8).toList(), (a) => openBrowseItem(context, ref, a)),
            ],
          ],
        );
      },
    );
  }
}
