import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../models/hist_entry.dart';
import '../models/track.dart';
import '../providers/core_providers.dart';
import '../providers/library_providers.dart';
import '../providers/music_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/cover_image.dart';
import '../widgets/detail_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/stats_share.dart';
import '../widgets/toast.dart';
import '../widgets/track_actions.dart';

class _TrackStat {
  _TrackStat(this.entry);
  final HistEntry entry;
  int plays = 0;
  int sec = 0;
}

class _ArtistStat {
  _ArtistStat(this.name);
  final String name;
  int plays = 0;
  int sec = 0;
}

class _Stats {
  int sec = 0;
  int plays = 0;
  final Map<String, _TrackStat> tracks = {};
  final Map<String, _ArtistStat> artists = {};
  final List<int> hours = List<int>.filled(24, 0);

  List<_TrackStat> get topTracks {
    final l = tracks.values.toList()
      ..sort((a, b) => b.plays != a.plays ? b.plays.compareTo(a.plays) : b.sec.compareTo(a.sec));
    return l;
  }

  List<_ArtistStat> get topArtists {
    final l = artists.values.toList()..sort((a, b) => b.sec.compareTo(a.sec));
    return l;
  }
}

_Stats _compute(List<HistEntry> list) {
  final st = _Stats();
  for (final e in list) {
    st.plays++;
    st.sec += e.seconds;
    final t = st.tracks.putIfAbsent(e.id, () => _TrackStat(e));
    t.plays++;
    t.sec += e.seconds;
    if (e.artist.isNotEmpty && e.artist != 'Unknown') {
      final a = st.artists.putIfAbsent(e.artist, () => _ArtistStat(e.artist));
      a.plays++;
      a.sec += e.seconds;
    }
    st.hours[e.time.hour]++;
  }
  return st;
}

int _streak(List<HistEntry> all) {
  final days = <String>{};
  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  for (final e in all) {
    days.add(key(e.time));
  }
  var d = DateTime.now();
  if (!days.contains(key(d))) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (days.contains(key(d))) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

String formatListen(int sec) {
  if (sec < 60) return '$sec dtk';
  final m = sec ~/ 60;
  if (m < 60) return '$m mnt';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h jam' : '$h jam $r mnt';
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  if (d.inDays < 7) return '${d.inDays} hari lalu';
  return '${t.day}/${t.month}/${t.year}';
}

const List<(String, String)> _ranges = [
  ('7', '7 hari'),
  ('30', '30 hari'),
  ('365', 'Tahun ini'),
  ('0', 'Semua'),
];

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _range = '30';

  List<HistEntry> _inRange(List<HistEntry> all) {
    if (_range == '0') return all;
    final now = DateTime.now();
    final from = _range == '365'
        ? DateTime(now.year, 1, 1)
        : now.subtract(Duration(days: int.parse(_range)));
    return all.where((e) => !e.time.isBefore(from)).toList();
  }

  Widget _summary(String label, String value) => Expanded(
        child: GlassCard(
          blur: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: T.ink)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.ink3)),
            ],
          ),
        ),
      );

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 10),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
      );

  @override
  Widget build(BuildContext context) {
    ref.watch(historyVersionProvider);
    final hs = ref.read(historyServiceProvider);
    final all = hs.entries();
    final list = _inRange(all);
    final st = _compute(list);
    final handler = ref.read(audioHandlerProvider);
    final topTracks = st.topTracks.take(10).toList();
    final topArtists = st.topArtists.take(5).toList();
    var peak = 0;
    for (var h = 0; h < 24; h++) {
      if (st.hours[h] > st.hours[peak]) peak = h;
    }
    final queue = topTracks.map((e) => e.entry.track).toList();

    return DetailScaffold(
      title: 'Statistik',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final r in _ranges) ...[
                AppChip(label: r.$2, active: _range == r.$1, onTap: () => setState(() => _range = r.$1)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const GlassCard(
            child: Text(
                'Belum ada data di periode ini. Lagu dihitung setelah kamu mendengarkannya sekitar 30 detik. Data tersimpan di akunmu dan ikut sinkron antar perangkat.',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
          )
        else ...[
          Row(children: [
            _summary('Waktu mendengar', formatListen(st.sec)),
            const SizedBox(width: 10),
            _summary('Total putar', '${st.plays}'),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _summary('Lagu unik', '${st.tracks.length}'),
            const SizedBox(width: 10),
            _summary('Beruntun', '${_streak(all)} hari'),
          ]),
          const SizedBox(height: 10),
          GlassCard(
            blur: false,
            child: Row(
              children: [
                const Icon(AppIcons.history, size: 24, color: T.accent2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Paling sering mendengar sekitar pukul ${peak.toString().padLeft(2, '0')}.00',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: T.ink2)),
                ),
              ],
            ),
          ),
          if (topArtists.isNotEmpty) ...[
            _heading('Artis teratas'),
            for (var i = 0; i < topArtists.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  blur: false,
                  shadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 24,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800, color: T.accent2))),
                      Expanded(
                        child: Text(topArtists[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
                      ),
                      Text(formatListen(topArtists[i].sec),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.ink3)),
                    ],
                  ),
                ),
              ),
          ],
          _heading('Lagu teratas'),
          for (var i = 0; i < topTracks.length; i++)
            _StatTrackRow(
              index: i + 1,
              track: topTracks[i].entry.track,
              right: '${topTracks[i].plays}x',
              onTap: () => handler.playQueue(queue, i),
            ),
          _heading('Riwayat putar'),
          for (var i = 0; i < list.length && i < 50; i++)
            _StatTrackRow(
              index: null,
              track: list[i].track,
              right: _ago(list[i].time),
              onTap: () => handler.playQueue([list[i].track], 0),
            ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Bagikan statistik (gambar)',
            onPressed: () => showStatsShare(
              context,
              StatsShareData(
                rangeLabel: _ranges.firstWhere((r) => r.$1 == _range).$2,
                listenText: formatListen(st.sec),
                plays: st.plays,
                uniqueTracks: st.tracks.length,
                streakDays: _streak(all),
                peakHour: peak,
                username: ref.read(authProvider).user?.username,
                topArtists: [for (final a in st.topArtists.take(3)) a.name],
                topTracks: [
                  for (final t in topTracks.take(5))
                    StatsShareTrack(t.entry.track.title, t.entry.track.artist, t.entry.track.cover, t.plays),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Hapus riwayat',
            danger: true,
            onPressed: () async {
              final ok = await showConfirm(context,
                  title: 'Hapus riwayat putar?',
                  message:
                      'Semua riwayat dan statistik dihapus. Jika sudah login, ikut terhapus di semua perangkat.');
              if (!ok) return;
              await hs.clear();
              if (context.mounted) showToast(context, 'Riwayat dihapus');
            },
          ),
        ],
      ],
    );
  }
}

class _StatTrackRow extends StatelessWidget {
  const _StatTrackRow({required this.index, required this.track, required this.right, required this.onTap});
  final int? index;
  final Track track;
  final String right;
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
            if (index != null)
              SizedBox(
                  width: 24,
                  child: Text('$index',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: T.accent2))),
            CoverImage(track.cover, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink)),
                  const SizedBox(height: 2),
                  Text(track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(right,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.ink3)),
          ],
        ),
      ),
    );
  }
}
