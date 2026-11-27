import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/avatar_util.dart';
import '../core/config.dart';
import '../core/theme/tokens.dart';
import '../models/user.dart';
import '../core/icons.dart';
import '../providers/core_providers.dart';
import '../providers/library_providers.dart';
import '../providers/moderation_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/moderation_sheets.dart';
import '../widgets/page_header.dart';
import '../widgets/toast.dart';
import '../widgets/track_actions.dart';
import '../widgets/user_avatar.dart';
import 'auth_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final bottomPad = 66 + 10 + MediaQuery.paddingOf(context).bottom + 24;
    return Column(
      children: [
        const PageHeader(title: 'Profil'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
            children: [
              if (user == null) const AuthCard() else _AccountCard(user: user),
              const SizedBox(height: 14),
              if (user != null) ...[
                const _SyncCard(),
                const SizedBox(height: 14),
              ],
              GlassCard(
                onTap: () => context.push('/stats'),
                child: const Row(
                  children: [
                    Icon(AppIcons.stats, size: 26, color: T.accent2),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Statistik & riwayat putar',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: T.ink)),
                    ),
                    Icon(AppIcons.chevronRight, size: 22, color: T.ink4),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _BatteryCard(),
              const SizedBox(height: 14),
              const _MoreCard(),
              const SizedBox(height: 14),
              const GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tentang',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
                    SizedBox(height: 8),
                    Text('Auzify v${AppConfig.appVersion} (web ${AppConfig.webVersion})',
                        style: TextStyle(fontSize: 13, color: T.ink2, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('Server: ${AppConfig.apiBase}',
                        style: TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                    SizedBox(height: 6),
                    Text('Auzify tidak berafiliasi dengan YouTube atau Google.',
                        style: TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.user});
  final AppUser user;

  Future<void> _logoutAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari semua perangkat?'),
        content: const Text('Semua perangkat lain (termasuk web) akan keluar dari akunmu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar', style: TextStyle(color: T.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(authProvider.notifier).signOutAll();
    if (context.mounted && err != null) showToast(context, err);
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 90);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final data = await prepareAvatarDataUrl(bytes);
      if (!context.mounted) return;
      if (data == null) {
        showToast(context, 'Foto tidak bisa diproses. Coba foto lain.');
        return;
      }
      final err = await ref.read(authProvider.notifier).uploadAvatar(data);
      if (!context.mounted) return;
      showToast(context, err ?? 'Foto profil diperbarui');
    } catch (_) {
      if (context.mounted) showToast(context, 'Gagal memilih foto.');
    }
  }

  Future<void> _avatarMenu(BuildContext context, WidgetRef ref, AppUser user) async {
    final nav = Navigator.of(context, rootNavigator: true);
    await showGlassSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetItem(
            icon: AppIcons.camera,
            label: 'Pilih foto dari galeri',
            onTap: () {
              nav.pop();
              _pickAvatar(context, ref);
            },
          ),
          if (user.avatar != null)
            SheetItem(
              icon: AppIcons.trash,
              label: 'Hapus foto',
              danger: true,
              onTap: () async {
                nav.pop();
                final err = await ref.read(authProvider.notifier).removeAvatar();
                if (context.mounted) showToast(context, err ?? 'Foto profil dihapus');
              },
            ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = await showDialog<String>(
      context: context,
      barrierColor: T.scrim,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null) return;
    final err = await ref.read(authProvider.notifier).deleteAccount(password);
    if (!context.mounted) return;
    showToast(context, err ?? 'Akunmu sudah dihapus.');
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<(String, String)>(
      context: context,
      barrierColor: T.scrim,
      builder: (_) => const _PasswordDialog(),
    );
    if (res == null) return;
    final err = await ref.read(authProvider.notifier).changePassword(res.$1, res.$2);
    if (!context.mounted) return;
    showToast(context, err ?? 'Password diubah. Perangkat lain keluar otomatis.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _avatarMenu(context, ref, user),
                child: Stack(
                  children: [
                    UserAvatar(name: user.username, path: user.avatar, size: 56),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: T.accent,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(AppIcons.camera, size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
                    const SizedBox(height: 2),
                    const Text('Akun tersambung',
                        style: TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SecondaryButton(
              label: 'Ubah password', onPressed: () => _changePassword(context, ref)),
          const SizedBox(height: 8),
          SecondaryButton(
              label: 'Keluar', onPressed: () => ref.read(authProvider.notifier).signOut()),
          const SizedBox(height: 8),
          SecondaryButton(
              label: 'Pengguna diblokir',
              onPressed: () {
                ref.read(blockedProvider.notifier).load();
                showGlassSheet(context, const BlockedSheet());
              }),
          const SizedBox(height: 8),
          SecondaryButton(
              label: 'Keluar dari semua perangkat',
              danger: true,
              onPressed: () => _logoutAll(context, ref)),
          const SizedBox(height: 8),
          SecondaryButton(
              label: 'Hapus akun',
              danger: true,
              onPressed: () => _deleteAccount(context, ref)),
        ],
      ),
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  String _label(DateTime? t) {
    if (t == null) return 'Belum pernah sinkron di sesi ini';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Tersinkron baru saja';
    if (d.inMinutes < 60) return 'Tersinkron ${d.inMinutes} menit lalu';
    return 'Tersinkron ${d.inHours} jam lalu';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.read(syncServiceProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sinkronisasi akun',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
          const SizedBox(height: 6),
          ValueListenableBuilder<DateTime?>(
            valueListenable: sync.lastSync,
            builder: (_, t, __) => ValueListenableBuilder<String>(
              valueListenable: sync.error,
              builder: (_, err, __) => Text(err.isNotEmpty ? err : _label(t),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: err.isNotEmpty ? T.danger : T.ink3)),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: sync.busyNotifier,
            builder: (_, busy, __) => SecondaryButton(
              label: busy ? 'Menyinkronkan…' : 'Sinkronkan sekarang',
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await sync.sync();
                      if (context.mounted) {
                        showToast(context, ok ? 'Data akun disinkronkan' : 'Sinkron gagal, coba lagi');
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _show = false;
  String _error = '';

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: T.ink4, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, .78),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.accent)),
      );

  void _submit() {
    if (_old.text.isEmpty) {
      setState(() => _error = 'Isi password lama.');
    } else if (_new.text.length < 8 || _new.text.length > 128) {
      setState(() => _error = 'Password baru 8–128 karakter.');
    } else if (_new.text != _again.text) {
      setState(() => _error = 'Konfirmasi password tidak sama.');
    } else {
      Navigator.pop(context, (_old.text, _new.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600);
    return AlertDialog(
      backgroundColor: T.bg1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
      title: const Text('Ubah password',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _old, obscureText: !_show, style: style, decoration: _dec('Password lama')),
            const SizedBox(height: 10),
            TextField(controller: _new, obscureText: !_show, style: style, decoration: _dec('Password baru')),
            const SizedBox(height: 10),
            TextField(
                controller: _again,
                obscureText: !_show,
                style: style,
                decoration: _dec('Ulangi password baru'),
                onSubmitted: (_) => _submit()),
            const SizedBox(height: 6),
            Row(
              children: [
                Switch(
                  value: _show,
                  onChanged: (v) => setState(() => _show = v),
                  activeTrackColor: T.accent,
                  inactiveTrackColor: T.accentSoft,
                ),
                const Text('Tampilkan',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.ink2)),
              ],
            ),
            if (_error.isNotEmpty)
              Text(_error,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: T.ink3, fontWeight: FontWeight.w700))),
        TextButton(
            onPressed: _submit,
            child: const Text('Simpan', style: TextStyle(color: T.accent2, fontWeight: FontWeight.w800))),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _pass = TextEditingController();
  bool _show = false;
  String _error = '';

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: T.bg1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
      title: const Text('Hapus akun permanen?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Akun, data sinkronisasi (suka, playlist, riwayat), pesan chat, dan daftar blokirmu akan dihapus dan tidak bisa dikembalikan. Masukkan password untuk melanjutkan.',
                style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500, color: T.ink2)),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: !_show,
              style: const TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: T.ink4, fontWeight: FontWeight.w500),
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, .78),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: const BorderSide(color: T.line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: const BorderSide(color: T.line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: const BorderSide(color: T.accent)),
                suffixIcon: IconButton(
                  icon: Icon(_show ? AppIcons.eyeOff : AppIcons.eye, size: 20, color: T.ink3),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.danger)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: T.ink3, fontWeight: FontWeight.w700))),
        TextButton(
            onPressed: () {
              if (_pass.text.isEmpty) {
                setState(() => _error = 'Isi password.');
              } else {
                Navigator.pop(context, _pass.text);
              }
            },
            child: const Text('Hapus akun', style: TextStyle(color: T.danger, fontWeight: FontWeight.w800))),
      ],
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard();

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w500, color: T.ink2);
    return const GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Musik di latar belakang',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
          SizedBox(height: 8),
          Text('Agar musik tetap jalan saat layar mati:', style: body),
          SizedBox(height: 6),
          Text('• Pengaturan → Aplikasi → Auzify → Baterai → pilih Tidak dibatasi.', style: body),
          Text('• Izinkan notifikasi Auzify (kontrol di layar kunci).', style: body),
          Text('• Jangan usap-tutup paksa aplikasinya; cukup matikan layar atau pindah aplikasi.', style: body),
        ],
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard();

  Future<void> _clearCache(BuildContext context) async {
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      if (context.mounted) showToast(context, 'Cache gambar dibersihkan');
    } catch (_) {
      if (context.mounted) showToast(context, 'Gagal membersihkan cache.');
    }
  }

  Future<void> _openWeb(BuildContext context, String path) async {
    final url = AppConfig.absUrl(path);
    final ok = url != null &&
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showToast(context, 'Tidak bisa membuka tautan.');
  }

  Future<void> _openChannel(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse('https://whatsapp.com/channel/0029VbAYbLc7tkizhltuyV1b'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) showToast(context, 'Tidak bisa membuka tautan.');
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecondaryButton(label: 'Gabung Channel WhatsApp', onPressed: () => _openChannel(context)),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Bersihkan cache gambar', onPressed: () => _clearCache(context)),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Kebijakan Privasi', onPressed: () => _openWeb(context, '/privacy')),
          const SizedBox(height: 8),
          SecondaryButton(
              label: 'Syarat & aturan komunitas', onPressed: () => _openWeb(context, '/terms')),
          const SizedBox(height: 8),
          SecondaryButton(
              label: 'Hapus akun (lewat web)', onPressed: () => _openWeb(context, '/hapus-akun')),
        ],
      ),
    );
  }
}
