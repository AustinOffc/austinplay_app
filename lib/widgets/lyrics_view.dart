import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/lyric_words.dart';
import '../core/theme/tokens.dart';
import '../models/lyrics.dart';
import '../providers/lyrics_prefs.dart';
import '../providers/music_providers.dart';
import 'lyrics_tools.dart';

/// Lirik sinkron per baris: baris aktif tegas, lainnya redup, ketuk baris = seek,
/// auto-scroll mulus, terjemahan di bawah baris (bila server menyediakan).
/// Pakai `key: ValueKey(videoId)` di pemanggil agar state ter-reset per lagu.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.onSeek,
    this.cover = '',
  });
  final String videoId;
  final String title;
  final String artist;
  final String cover;
  final Future<void> Function(Duration) onSeek;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  List<GlobalKey> _keys = [];
  int _active = -1;
  bool _showTr = true;

  (String, String, String) get _key => (widget.videoId, widget.title, widget.artist);

  void _scrollTo(int i) {
    if (!mounted || i < 0 || i >= _keys.length) return;
    final ctx = _keys[i].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        alignment: 0.35, duration: const Duration(milliseconds: 380), curve: T.ease);
  }

  int _indexAt(Lyrics l, Duration pos, double offset) {
    final t = pos.inMilliseconds / 1000.0 + offset;
    var idx = -1;
    for (var i = 0; i < l.lines.length; i++) {
      if (l.lines[i].time <= t) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(lyricsProvider(_key));
    final prefs = ref.watch(lyricsPrefsProvider);
    final offset = prefs.offsetFor(widget.videoId);
    final roman = prefs.roman ? ref.watch(romanProvider(_key)).valueOrNull : null;
    return res.when(
      loading: () => const Center(child: CircularProgressIndicator(color: T.accent, strokeWidth: 3)),
      error: (e, _) => _Message(
        text: ApiClient.messageOf(e),
        action: 'Coba lagi',
        onAction: () => ref.invalidate(lyricsProvider(_key)),
      ),
      data: (l) {
        if (l.isEmpty) return const _Message(text: 'Lirik untuk lagu ini belum tersedia.');
        if (_keys.length != l.lines.length) {
          _keys = List.generate(l.lines.length, (_) => GlobalKey());
        }
        final hasTr = l.lines.any((e) => e.translation.isNotEmpty);
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasTr) ...[
                  _Pill(
                    label: 'Terjemahan',
                    on: _showTr,
                    onTap: () => setState(() => _showTr = !_showTr),
                  ),
                  const SizedBox(width: 8),
                ],
                _Pill(
                  label: 'Aa',
                  on: false,
                  onTap: () => showLyricsTools(
                    context,
                    videoId: widget.videoId,
                    lyrics: l,
                    title: widget.title,
                    artist: widget.artist,
                    cover: widget.cover,
                    startIndex: _active,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: l.synced ? AudioService.position : null,
                initialData: Duration.zero,
                builder: (_, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final idx = l.synced ? _indexAt(l, pos, offset) : -1;
                  final nowSec = pos.inMilliseconds / 1000.0 + 0.18 + offset;
                  if (idx != _active) {
                    _active = idx;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(idx));
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < l.lines.length; i++)
                          _Line(
                            key: _keys[i],
                            line: l.lines[i],
                            active: !l.synced || i == idx,
                            passed: l.synced && i < idx,
                            showTr: _showTr,
                            roman: (roman != null && i < roman.length) ? roman[i] : '',
                            nowSec: (l.synced && prefs.words && i == idx) ? nowSec : null,
                            nextTime: i + 1 < l.lines.length ? l.lines[i + 1].time : null,
                            onTap: l.synced
                                ? () => widget.onSeek(Duration(
                                    milliseconds:
                                        math.max(0, ((l.lines[i].time - offset) * 1000).round())))
                                : null,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.line,
    required this.active,
    required this.passed,
    required this.showTr,
    this.roman = '',
    this.nowSec,
    this.nextTime,
    this.onTap,
  });
  final LyricLine line;
  final bool active;
  final bool passed;
  final bool showTr;
  final String roman;

  /// Posisi pemutaran (detik, sudah + geser waktu) bila baris ini disorot per kata; null = teks biasa.
  final double? nowSec;
  final double? nextTime;
  final VoidCallback? onTap;

  Widget _text() {
    final base = TextStyle(
        fontSize: active ? 22 : 20,
        height: 1.3,
        fontWeight: active ? FontWeight.w800 : FontWeight.w700,
        color: active ? T.ink : T.ink2);
    final t = nowSec;
    if (t == null) return Text(line.text, style: base);
    final words = splitWords(line.text);
    if (words.isEmpty) return Text(line.text, style: base);
    final dur = lyricLineDuration(line.time, nextTime, line.text);
    final prog = ((t - line.time) / dur).clamp(0.0, 1.0).toDouble();
    return Text.rich(TextSpan(
      style: base,
      children: [
        for (final w in words)
          TextSpan(
            text: w.text + w.gap,
            style: TextStyle(
              color: Color.lerp(
                  T.ink3, T.accent2, ((prog - w.a) / math.max(0.01, w.b - w.a)).clamp(0.0, 1.0).toDouble()),
            ),
          ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (line.text.trim().isEmpty) return const SizedBox(height: 14);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: active ? 1 : (passed ? 0.45 : 0.6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _text(),
              if (roman.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(roman,
                      style: const TextStyle(
                          fontSize: 13.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: T.accent2)),
                ),
              if (showTr && line.translation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(line.translation,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: T.ink3)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: T.ink3)),
              if (action != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onAction,
                  child: Text(action!,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: T.accent2)),
                ),
              ],
            ],
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? T.accent : T.glass,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: on ? T.accent : T.glassEdge),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? Colors.white : T.ink2)),
        ),
      );
}
