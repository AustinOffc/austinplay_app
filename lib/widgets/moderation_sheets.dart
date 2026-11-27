import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../core/api_client.dart';
import '../providers/moderation_providers.dart';
import '../services/moderation_service.dart';
import 'toast.dart';
import 'track_actions.dart';

/// Pilih alasan lalu kirim laporan lewat [send]. Menampilkan toast hasilnya.
Future<void> showReportSheet(
  BuildContext context, {
  required Future<void> Function(String reason) send,
}) {
  final nav = Navigator.of(context, rootNavigator: true);
  return showGlassSheet(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Laporkan karena…',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
        ),
        for (final r in ModerationService.reasons)
          SheetItem(
            icon: AppIcons.flag,
            label: r.$2,
            onTap: () async {
              nav.pop();
              String msg;
              try {
                await send(r.$1);
                msg = 'Laporan terkirim. Terima kasih.';
              } catch (e) {
                msg = ApiClient.messageOf(e);
              }
              if (context.mounted) showToast(context, msg);
            },
          ),
      ],
    ),
  );
}

/// Daftar pengguna yang diblokir + tombol buka blokir.
class BlockedSheet extends ConsumerWidget {
  const BlockedSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(blockedProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Pengguna diblokir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Belum ada pengguna yang kamu blokir.',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: T.ink3)),
          ),
        for (final b in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(b.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: T.ink)),
                ),
                TextButton(
                  onPressed: () async {
                    final err = await ref.read(blockedProvider.notifier).unblock(b.id);
                    if (context.mounted && err != null) showToast(context, err);
                  },
                  child: const Text('Buka blokir',
                      style: TextStyle(color: T.accent2, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
