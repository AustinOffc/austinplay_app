import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/theme/tokens.dart';
import '../providers/core_providers.dart';
import 'toast.dart';

const String _playUrl = 'https://play.google.com/store/apps/details?id=id.austin.auzify';

List<int> _parts(String v) {
  final p = v.split('+').first.split('.');
  return [for (var i = 0; i < 3; i++) i < p.length ? (int.tryParse(p[i]) ?? 0) : 0];
}

/// true bila versi [a] lebih lama dari [b].
bool versionOlder(String a, String b) {
  final x = _parts(a);
  final y = _parts(b);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] < y[i];
  }
  return false;
}

/// Membaca GET /api/app/config (patch backend, opsional). Gagal = diam saja.
/// minVersion → dialog wajib-update; latestVersion → ajakan; notice → toast.
Future<void> checkAppNotice(BuildContext context, WidgetRef ref) async {
  try {
    final r = await ref.read(apiClientProvider).get('/api/app/config', soft401: true);
    if (!context.mounted) return;
    final min = (r['minVersion'] ?? '').toString();
    final latest = (r['latestVersion'] ?? '').toString();
    final notice = (r['notice'] ?? '').toString().trim();
    if (min.isNotEmpty && versionOlder(AppConfig.appVersion, min)) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: T.scrim,
        builder: (ctx) => PopScope(
          canPop: false,
          child: _UpdateDialog(forced: true, onUpdate: () => _open(ctx)),
        ),
      );
      return;
    }
    if (latest.isNotEmpty && versionOlder(AppConfig.appVersion, latest)) {
      await showDialog<void>(
        context: context,
        barrierColor: T.scrim,
        builder: (ctx) => _UpdateDialog(forced: false, onUpdate: () => _open(ctx)),
      );
    }
    if (notice.isNotEmpty && context.mounted) showToast(context, notice);
  } catch (_) {
    // Endpoint belum dipasang / offline: abaikan.
  }
}

Future<void> _open(BuildContext ctx) async {
  await launchUrl(Uri.parse(_playUrl), mode: LaunchMode.externalApplication);
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.forced, required this.onUpdate});
  final bool forced;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: T.bg1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
      title: Text(forced ? 'Perbarui aplikasi' : 'Versi baru tersedia',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
      content: Text(
          forced
              ? 'Versi Auzify ini sudah tidak didukung. Perbarui dulu untuk melanjutkan.'
              : 'Ada versi Auzify yang lebih baru dengan perbaikan dan fitur baru.',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: T.ink2)),
      actions: [
        if (!forced)
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti', style: TextStyle(color: T.ink3, fontWeight: FontWeight.w700))),
        TextButton(
            onPressed: onUpdate,
            child: const Text('Perbarui',
                style: TextStyle(color: T.accent2, fontWeight: FontWeight.w800))),
      ],
    );
  }
}
