import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/tokens.dart';
import '../models/lyrics.dart';
import '../providers/lyrics_prefs.dart';
import 'buttons.dart';
import 'cover_image.dart';
import 'toast.dart';
import 'track_actions.dart';

const TextStyle _title = TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink);
const TextStyle _label = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: T.ink2);
const TextStyle _hint = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3);

/// Alat lirik (tombol "Aa"): geser waktu per lagu, sorot per kata, romanisasi, bagikan sebagai gambar.
Future<void> showLyricsTools(
  BuildContext context, {
  required String videoId,
  required Lyrics lyrics,
  required String title,
  required String artist,
  required String cover,
  int startIndex = 0,
}) {
  return showGlassSheet(
    context,
    LyricsToolsSheet(
      videoId: videoId,
      lyrics: lyrics,
      title: title,
      artist: artist,
      cover: cover,
      startIndex: startIndex,
    ),
  );
}

class LyricsToolsSheet extends ConsumerWidget {
  const LyricsToolsSheet({
    super.key,
    required this.videoId,
    required this.lyrics,
    required this.title,
    required this.artist,
    required this.cover,
    required this.startIndex,
  });
  final String videoId;
  final Lyrics lyrics;
  final String title;
  final String artist;
  final String cover;
  final int startIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(lyricsPrefsProvider);
    final ctrl = ref.read(lyricsPrefsProvider.notifier);
    final nav = Navigator.of(context, rootNavigator: true);
    final off = prefs.offsetFor(videoId);
    final offLabel = '${off > 0 ? '+' : ''}${off.toStringAsFixed(2)} dtk';

    Widget mini(String text, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: T.glass,
              borderRadius: BorderRadius.circular(T.rPill),
              border: Border.all(color: T.glassEdge),
            ),
            child: Text(text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: T.ink2)),
          ),
        );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Alat lirik', style: _title),
          const SizedBox(height: 14),
          if (lyrics.synced) ...[
            const Text('Geser waktu lirik', style: _label),
            const SizedBox(height: 2),
            const Text('+ = lirik muncul lebih cepat, − = lebih lambat (tersimpan per lagu).', style: _hint),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                mini('−0,25', () => ctrl.nudge(videoId, -0.25)),
                Text(offLabel, style: _label),
                mini('+0,25', () => ctrl.nudge(videoId, 0.25)),
                mini('Reset', () => ctrl.resetOffset(videoId)),
              ],
            ),
            const SizedBox(height: 14),
            _SwitchRow(
              label: 'Sorot per kata',
              hint: 'Perkiraan dari durasi baris (sumber lirik hanya per baris).',
              value: prefs.words,
              onChanged: ctrl.setWords,
            ),
          ],
          _SwitchRow(
            label: 'Romanisasi',
            hint: 'Huruf Latin untuk lirik Jepang/Korea/Arab dan lainnya.',
            value: prefs.roman,
            onChanged: ctrl.setRoman,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Bagikan lirik sebagai gambar',
            onPressed: () {
              nav.pop();
              showLyricShare(
                nav.context,
                lyrics: lyrics,
                title: title,
                artist: artist,
                cover: cover,
                startIndex: startIndex,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.hint, required this.value, required this.onChanged});
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(label, style: _label), Text(hint, style: _hint)],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: T.accent,
              inactiveTrackColor: T.accentSoft,
            ),
          ],
        ),
      );
}

// ───────────────────── Bagikan lirik sebagai gambar ─────────────────────

Future<void> showLyricShare(
  BuildContext context, {
  required Lyrics lyrics,
  required String title,
  required String artist,
  required String cover,
  int startIndex = 0,
}) {
  return showGlassSheet(
    context,
    _LyricShareSheet(lyrics: lyrics, title: title, artist: artist, cover: cover, startIndex: startIndex),
  );
}

class _LyricShareSheet extends StatefulWidget {
  const _LyricShareSheet({
    required this.lyrics,
    required this.title,
    required this.artist,
    required this.cover,
    required this.startIndex,
  });
  final Lyrics lyrics;
  final String title;
  final String artist;
  final String cover;
  final int startIndex;

  @override
  State<_LyricShareSheet> createState() => _LyricShareSheetState();
}

class _LyricShareSheetState extends State<_LyricShareSheet> {
  static const int _max = 8;
  final Set<int> _picked = {};
  final GlobalKey _boundary = GlobalKey();
  bool _preview = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final lines = widget.lyrics.lines;
    var i = widget.startIndex < 0 ? 0 : widget.startIndex;
    while (i < lines.length && _picked.length < 3) {
      if (lines[i].text.trim().isNotEmpty) _picked.add(i);
      i++;
    }
  }

  void _toggle(int i) {
    setState(() {
      if (_picked.contains(i)) {
        _picked.remove(i);
      } else if (_picked.length >= _max) {
        showToast(context, 'Maksimal $_max baris');
      } else {
        _picked.add(i);
      }
    });
  }

  List<String> get _pickedTexts {
    final idx = _picked.toList()..sort();
    return [for (final i in idx) widget.lyrics.lines[i].text.trim()];
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final b = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (b == null) return;
      final img = await b.toImage(pixelRatio: 3);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) return;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/auzify-lirik.png');
      await f.writeAsBytes(bd.buffer.asUint8List(), flush: true);
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')],
          text: '${widget.title} — ${widget.artist}');
    } catch (_) {
      if (mounted) showToast(context, 'Gagal membuat gambar');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.5;
    if (_preview) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Gambar lirik', style: _title),
          const SizedBox(height: 10),
          SizedBox(
            height: maxH,
            child: SingleChildScrollView(
              child: Center(
                child: RepaintBoundary(
                  key: _boundary,
                  child: _LyricCard(
                    lines: _pickedTexts,
                    title: widget.title,
                    artist: widget.artist,
                    cover: widget.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: _busy ? 'Menyiapkan…' : 'Bagikan', onPressed: _busy ? null : _share),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Pilih baris lagi', onPressed: () => setState(() => _preview = false)),
        ],
      );
    }
    final lines = widget.lyrics.lines;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pilih baris lirik (${_picked.length}/$_max)', style: _title),
        const SizedBox(height: 8),
        SizedBox(
          height: maxH,
          child: ListView.builder(
            itemCount: lines.length,
            itemBuilder: (_, i) {
              final t = lines[i].text.trim();
              if (t.isEmpty) return const SizedBox.shrink();
              final on = _picked.contains(i);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggle(i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: on ? T.accentSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(T.rMd),
                    border: Border.all(color: on ? T.accent : T.line),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                          color: on ? T.ink : T.ink2)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Buat gambar',
          onPressed: () {
            if (_picked.isEmpty) {
              showToast(context, 'Pilih minimal satu baris');
              return;
            }
            setState(() => _preview = true);
          },
        ),
      ],
    );
  }
}

/// Kartu 360 dp (diambil 3× → 1080 px): latar cover buram + teks putih, seperti di web.
class _LyricCard extends StatelessWidget {
  const _LyricCard({required this.lines, required this.title, required this.artist, required this.cover});
  final List<String> lines;
  final String title;
  final String artist;
  final String cover;

  Widget _background() {
    if (cover.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD4467A), Color(0xFF3A2530)],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
            child: CoverImage(cover, radius: 0),
          ),
        ),
        const ColoredBox(color: Color.fromRGBO(20, 8, 14, .55)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Stack(
        children: [
          Positioned.fill(child: _background()),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 44, 30, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(l,
                          style: const TextStyle(
                              fontSize: 24, height: 1.3, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (cover.isNotEmpty) ...[
                        CoverImage(cover, size: 52, radius: 12),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                            Text(artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromRGBO(255, 255, 255, .75))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('AUZIFY',
                      style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                          color: Color.fromRGBO(255, 255, 255, .6))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
