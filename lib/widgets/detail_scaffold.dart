import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../providers/music_providers.dart';
import 'app_background.dart';
import 'chips.dart';
import 'mini_player.dart';

/// Kerangka halaman detail (Artis/Album) di luar shell: tombol kembali + mini player di bawah.
class DetailScaffold extends ConsumerWidget {
  const DetailScaffold({super.key, required this.title, required this.children, this.onShare});
  final String title;
  final List<Widget> children;

  /// Bila diisi, tombol Bagikan tampil di kanan header.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlayer = ref.watch(hasPlayerProvider);
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 10, 16, 6),
              child: Row(
                children: [
                  GlassIconButton(icon: AppIcons.back, onTap: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: T.ink)),
                  ),
                  if (onShare != null) ...[
                    const SizedBox(width: 8),
                    GlassIconButton(icon: AppIcons.share, onTap: onShare!),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, (hasPlayer ? 84 : 16) + bottom + 12),
                children: children,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: hasPlayer
          ? Padding(padding: EdgeInsets.only(bottom: bottom), child: const MiniPlayer())
          : null,
    );
  }
}

/// Satu baris tombol Putar / Acak.
class PlayShuffleRow extends StatelessWidget {
  const PlayShuffleRow({super.key, required this.onPlay, required this.onShuffle});
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
      btn('Putar', AppIcons.play, true, onPlay),
      const SizedBox(width: 10),
      btn('Acak', AppIcons.shuffle, false, onShuffle),
    ]);
  }
}
