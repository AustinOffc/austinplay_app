import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/tokens.dart';
import 'buttons.dart';
import 'cover_image.dart';
import 'toast.dart';
import 'track_actions.dart';

class StatsShareTrack {
  const StatsShareTrack(this.title, this.artist, this.cover, this.plays);
  final String title;
  final String artist;
  final String cover;
  final int plays;
}

/// Ringkasan statistik yang dibagikan sebagai gambar ("Wrapped").
class StatsShareData {
  const StatsShareData({
    required this.rangeLabel,
    required this.listenText,
    required this.plays,
    required this.uniqueTracks,
    required this.streakDays,
    required this.peakHour,
    required this.topTracks,
    required this.topArtists,
    this.username,
  });
  final String rangeLabel;
  final String listenText;
  final int plays;
  final int uniqueTracks;
  final int streakDays;
  final int peakHour;
  final List<StatsShareTrack> topTracks;
  final List<String> topArtists;
  final String? username;
}

Future<void> showStatsShare(BuildContext context, StatsShareData data) =>
    showGlassSheet(context, _StatsShareSheet(data: data));

class _StatsShareSheet extends StatefulWidget {
  const _StatsShareSheet({required this.data});
  final StatsShareData data;
  @override
  State<_StatsShareSheet> createState() => _StatsShareSheetState();
}

class _StatsShareSheetState extends State<_StatsShareSheet> {
  final GlobalKey _boundary = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final b = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (b == null) return;
      final img = await b.toImage(pixelRatio: 3);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/auzify-wrapped.png');
      await f.writeAsBytes(bd.buffer.asUint8List(), flush: true);
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')],
          text: 'Statistik musikku di Auzify (${widget.data.rangeLabel})');
    } catch (_) {
      if (mounted) showToast(context, 'Gagal membuat gambar');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.58;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Bagikan statistik',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
        const SizedBox(height: 10),
        SizedBox(
          height: maxH,
          child: SingleChildScrollView(
            child: Center(
              child: RepaintBoundary(key: _boundary, child: _WrappedCard(data: widget.data)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: _busy ? 'Menyiapkan…' : 'Bagikan', onPressed: _busy ? null : _share),
      ],
    );
  }
}

class _WrappedCard extends StatelessWidget {
  const _WrappedCard({required this.data});
  final StatsShareData data;

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: T.ink)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.ink3)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-.34, -1),
          end: Alignment(.34, 1),
          stops: [0, .46, 1],
          colors: [T.bg1, T.bg2, T.bg3],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wrapped · ${data.rangeLabel}',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: T.accent2, letterSpacing: .2)),
          if (data.username != null && data.username!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('@${data.username}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.ink3)),
          ],
          const SizedBox(height: 14),
          Text(data.listenText,
              style: const TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: T.ink, height: 1.05)),
          const Text('waktu mendengar',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.ink3)),
          const SizedBox(height: 18),
          Row(children: [
            _stat('${data.plays}', 'total putar'),
            _stat('${data.uniqueTracks}', 'lagu unik'),
            _stat('${data.streakDays} hari', 'beruntun'),
          ]),
          if (data.topArtists.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Artis teratas',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: T.ink)),
            const SizedBox(height: 8),
            for (var i = 0; i < data.topArtists.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  SizedBox(
                      width: 22,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800, color: T.accent2))),
                  Expanded(
                    child: Text(data.topArtists[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: T.ink2)),
                  ),
                ]),
              ),
          ],
          if (data.topTracks.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Lagu teratas',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: T.ink)),
            const SizedBox(height: 8),
            for (var i = 0; i < data.topTracks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(
                      width: 22,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800, color: T.accent2))),
                  CoverImage(data.topTracks[i].cover, size: 38, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.topTracks[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: T.ink)),
                        Text(data.topTracks[i].artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: T.ink3)),
                      ],
                    ),
                  ),
                  Text('${data.topTracks[i].plays}x',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.ink3)),
                ]),
              ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                  'Paling sering mendengar sekitar pukul ${data.peakHour.toString().padLeft(2, '0')}.00',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.ink3)),
            ),
            const Text('Auzify',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: T.accent2)),
          ]),
        ],
      ),
    );
  }
}
