import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../providers/eq_providers.dart';
import '../providers/music_providers.dart';
import '../services/audio_handler.dart';
import 'chips.dart';
import 'cover_image.dart';
import 'track_actions.dart';

const TextStyle _title = TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink);
const TextStyle _hint = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: T.ink3);

Future<void> showQueueSheet(BuildContext context) => showGlassSheet(context, const QueueSheet());
Future<void> showSleepSheet(BuildContext context) => showGlassSheet(context, const SleepSheet());
Future<void> showEqSheet(BuildContext context) => showGlassSheet(context, const EqSheet());

String fmtSleep(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ───────────────────────── Antrean ─────────────────────────

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    ref.watch(mediaItemProvider); // sorot lagu yang sedang diputar
    final locked = handler.locked.value;
    final h = math.min(MediaQuery.sizeOf(context).height * 0.5, 460.0);
    return ValueListenableBuilder<int>(
      valueListenable: handler.queueVersion,
      builder: (context, _, __) {
        final tracks = handler.tracks;
        final cur = handler.currentIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Antrean (${tracks.length})', style: _title),
            const SizedBox(height: 4),
            Text(
                locked
                    ? 'Kamu tamu di Room — antrean diatur host.'
                    : 'Ketuk untuk memutar · tahan ikon ≡ untuk mengurutkan.',
                style: _hint),
            const SizedBox(height: 8),
            if (tracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Antrean kosong.', style: _hint),
              )
            else
              SizedBox(
                height: h,
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: tracks.length,
                  onReorder: handler.moveInQueue,
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    final isCur = i == cur;
                    return Container(
                      key: ValueKey('${t.videoId}#$i'),
                      color: Colors.transparent,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => handler.skipToQueueItem(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              CoverImage(t.cover, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isCur ? T.accent2 : T.ink)),
                                    Text(t.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3)),
                                  ],
                                ),
                              ),
                              if (isCur)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(AppIcons.play, size: 20, color: T.accent2),
                                )
                              else if (!locked)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => handler.removeFromQueue(i),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(AppIcons.close, size: 20, color: T.ink3),
                                  ),
                                ),
                              if (!locked)
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(AppIcons.drag, size: 22, color: T.ink4),
                                  ),
                                ),
                            ],
                          ),
                        ),
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

// ───────────────────────── Timer tidur ─────────────────────────

class SleepSheet extends ConsumerWidget {
  const SleepSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final nav = Navigator.of(context, rootNavigator: true);
    return ValueListenableBuilder<SleepState>(
      valueListenable: handler.sleep,
      builder: (context, st, _) {
        final status = st.endOfTrack
            ? 'Musik berhenti di akhir lagu ini.'
            : st.remaining != null
                ? 'Musik berhenti dalam ${fmtSleep(st.remaining!)}.'
                : 'Musik berhenti otomatis setelah waktu yang kamu pilih (volume dipelankan dulu).';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Timer tidur', style: _title),
            const SizedBox(height: 6),
            Text(status, style: _hint),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [15, 30, 45, 60])
                  AppChip(
                    label: '$m menit',
                    active: false,
                    onTap: () {
                      handler.startSleep(Duration(minutes: m));
                      nav.pop();
                    },
                  ),
                AppChip(
                  label: 'Akhir lagu',
                  active: st.endOfTrack,
                  onTap: () {
                    handler.sleepAtTrackEnd();
                    nav.pop();
                  },
                ),
                if (st.active)
                  AppChip(
                    label: 'Matikan timer',
                    active: false,
                    onTap: () {
                      handler.cancelSleep();
                      nav.pop();
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Equalizer ─────────────────────────

class EqSheet extends ConsumerStatefulWidget {
  const EqSheet({super.key});

  @override
  ConsumerState<EqSheet> createState() => _EqSheetState();
}

class _EqSheetState extends ConsumerState<EqSheet> {
  Map<int, double> _drag = {};

  static String _freq(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return '${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)}k';
    }
    return hz.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(eqProvider);
    final ctrl = ref.read(eqProvider.notifier);
    if (!st.ready) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Equalizer', style: _title),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
                'Equalizer baru tersedia setelah sebuah lagu mulai diputar (dan hanya di perangkat Android yang mendukung).',
                style: _hint),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Equalizer', style: _title)),
            Switch(
              value: st.enabled,
              onChanged: ctrl.setEnabled,
              activeTrackColor: T.accent,
              inactiveTrackColor: T.accentSoft,
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in eqPresets.keys)
              AppChip(
                label: name,
                active: false,
                onTap: () {
                  setState(() => _drag = {});
                  unawaited(ctrl.applyPreset(name));
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: st.enabled ? 1 : 0.5,
          child: SizedBox(
            height: 200,
            child: Row(
              children: [
                for (var i = 0; i < st.bands.length; i++)
                  Expanded(
                    child: Column(
                      children: [
                        Text('${(_drag[i] ?? st.bands[i].gain).round()}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: T.ink3)),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                activeTrackColor: T.accent,
                                inactiveTrackColor: T.accentTint,
                                thumbColor: T.accent,
                                overlayColor: Colors.transparent,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: (_drag[i] ?? st.bands[i].gain).clamp(st.minDb, st.maxDb).toDouble(),
                                min: st.minDb,
                                max: st.maxDb,
                                onChanged: (v) {
                                  setState(() => _drag = {..._drag, i: v});
                                  unawaited(ctrl.setGain(i, v));
                                },
                                onChangeEnd: (_) => setState(() => _drag = {}),
                              ),
                            ),
                          ),
                        ),
                        Text(_freq(st.bands[i].centerHz),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: T.ink2)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Hz · gain dalam dB. Pengaturan tersimpan di perangkat ini.', style: _hint),
        ),
      ],
    );
  }
}
