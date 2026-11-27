import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../core/config.dart';
import '../core/icons.dart';
import '../core/layout.dart';
import '../core/theme/tokens.dart';
import '../models/room.dart';
import '../providers/core_providers.dart';
import '../providers/moderation_providers.dart';
import '../providers/music_providers.dart';
import '../providers/nav_providers.dart';
import '../providers/room_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/chips.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass_card.dart';
import '../widgets/moderation_sheets.dart';
import '../widgets/page_header.dart';
import '../widgets/toast.dart';
import '../widgets/track_actions.dart';
import '../widgets/user_avatar.dart';

const Color _green = Color(0xFF3DBE7A);

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: T.ink4, fontWeight: FontWeight.w500),
      counterText: '',
      filled: true,
      fillColor: const Color.fromRGBO(255, 255, 255, .78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.accent)),
    );

/// Room / Listen Together: lobi (buat, gabung, daftar room aktif) dan tampilan di dalam room.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consumePending();
    });
  }

  void _consumePending() {
    final code = ref.read(pendingJoinProvider);
    if (code == null || code.isEmpty) return;
    ref.read(pendingJoinProvider.notifier).state = null;
    unawaited(_join(code));
  }

  Future<void> _join(String code) async {
    final err = await ref.read(roomProvider.notifier).join(code);
    if (mounted && err != null) showToast(context, err);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingJoinProvider, (_, next) {
      if (next != null) _consumePending();
    });
    final phase = ref.watch(roomProvider.select((s) => s.phase));
    return Column(
      children: [
        PageHeader(
          title: 'Room',
          trailing: phase == RoomPhase.none ? null : const _HeaderActions(),
        ),
        Expanded(
          child: phase == RoomPhase.none
              ? _Lobby(onJoin: _join)
              : phase == RoomPhase.connecting
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: T.accent))
                  : const _InRoom(),
        ),
      ],
    );
  }
}

class _HeaderActions extends ConsumerWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(roomProvider.select((s) => s.code));
    return GlassIconButton(
      icon: AppIcons.share,
      onTap: () => _shareRoom(code),
    );
  }
}

void _shareRoom(String code) {
  final url = AppConfig.absUrl('/?together=$code') ?? code;
  Share.share('Dengarkan musik bareng di Auzify. Kode room: $code\n$url');
}

// ───────────────────────────── Lobi ─────────────────────────────

class _Lobby extends ConsumerStatefulWidget {
  const _Lobby({required this.onJoin});
  final Future<void> Function(String code) onJoin;

  @override
  ConsumerState<_Lobby> createState() => _LobbyState();
}

class _LobbyState extends ConsumerState<_Lobby> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String _visibility = 'private';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && ref.read(tabIndexProvider) == 3) ref.invalidate(publicRoomsProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final err = await ref
        .read(roomProvider.notifier)
        .create(visibility: _visibility, name: _name.text.trim());
    if (!mounted) return;
    if (err != null) showToast(context, err);
  }

  Future<void> _joinCode() async {
    final c = _code.text.trim();
    if (c.length < 4) {
      showToast(context, 'Masukkan kode room (6 karakter).');
      return;
    }
    await widget.onJoin(c);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(roomProvider.select((s) => s.busy));
    final loggedIn = ref.watch(authProvider.select((s) => s.loggedIn));
    final hasPlayer = ref.watch(hasPlayerProvider);
    final rooms = ref.watch(publicRoomsProvider);
    final list = rooms.valueOrNull;

    return RefreshIndicator(
      color: T.accent,
      onRefresh: () async => ref.refresh(publicRoomsProvider.future),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, contentBottomPad(context, withPlayer: hasPlayer)),
        children: [
          if (!loggedIn)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Tanpa login kamu masuk sebagai Tamu. Masuk lewat tab Profil agar nama & fotomu tampil.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.ink3),
              ),
            ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Buat room',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
                const SizedBox(height: 4),
                const Text('Kamu jadi host: lagu yang kamu putar diikuti semua anggota.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: T.ink3)),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600),
                  decoration: _dec('Nama room (opsional)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    AppChip(
                        label: 'Private',
                        active: _visibility == 'private',
                        onTap: () => setState(() => _visibility = 'private')),
                    const SizedBox(width: 8),
                    AppChip(
                        label: 'Public',
                        active: _visibility == 'public',
                        onTap: () => setState(() => _visibility = 'public')),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _visibility == 'public'
                      ? 'Tampil di daftar Room aktif selama host online.'
                      : 'Hanya bisa dimasuki lewat kode / tautan.',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: T.ink3),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Buat room', busy: busy, onPressed: _create),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Gabung dengan kode',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    _UpperCase(),
                  ],
                  onSubmitted: (_) => _joinCode(),
                  style: const TextStyle(
                      fontSize: 18, color: T.ink, fontWeight: FontWeight.w800, letterSpacing: 4),
                  decoration: _dec('KODE'),
                ),
                const SizedBox(height: 12),
                SecondaryButton(label: 'Gabung', onPressed: busy ? null : _joinCode),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Room aktif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
          ),
          if (list == null && rooms.isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: T.accent)),
            )
          else if (list == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Daftar room belum bisa dimuat. Tarik ke bawah untuk coba lagi.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.ink3)),
            )
          else if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Belum ada room publik yang aktif.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.ink3)),
            )
          else
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoomTile(room: r, onTap: () => widget.onJoin(r.code)),
              ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});
  final RoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tr = room.track;
    return GlassCard(
      blur: false,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          CoverImage(tr?.cover ?? '', size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: T.ink)),
                const SizedBox(height: 2),
                Text('${room.hostName} • ${room.listeners} pendengar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: T.ink3)),
                if (tr != null)
                  Text(tr.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: T.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (room.playing)
            const Icon(AppIcons.music, size: 18, color: T.accent2)
          else
            const Icon(AppIcons.chevronRight, size: 20, color: T.ink4),
        ],
      ),
    );
  }
}

// ───────────────────────────── Di dalam room ─────────────────────────────

class _InRoom extends ConsumerWidget {
  const _InRoom();

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final host = ref.read(roomProvider).isHost;
    final ok = await showConfirm(context,
        title: host ? 'Tutup room?' : 'Keluar dari room?',
        message: host
            ? 'Kamu host. Bila kamu keluar, room ditutup untuk semua anggota.'
            : 'Kamu berhenti mengikuti host.',
        action: 'Keluar');
    if (ok) await ref.read(roomProvider.notifier).leave();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(roomProvider);
    final hasPlayer = ref.watch(hasPlayerProvider);
    final p = st.play;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, contentBottomPad(context, withPlayer: hasPlayer)),
      children: [
        if (st.reconnecting)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Menyambungkan ulang ke room…',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.accent2)),
          ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(st.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: T.ink)),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: st.code));
                      showToast(context, 'Kode disalin');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: T.accentSoft,
                        borderRadius: BorderRadius.circular(T.rPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(st.code,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                  color: T.accent2)),
                          const SizedBox(width: 8),
                          const Icon(AppIcons.copy, size: 15, color: T.accent2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(st.visibility == 'public' ? AppIcons.public : AppIcons.lock,
                      size: 16, color: T.ink3),
                  const SizedBox(width: 4),
                  Text(st.visibility == 'public' ? 'Publik' : 'Privat',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.ink3)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Sedang diputar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
              const SizedBox(height: 12),
              if (p == null)
                Text(
                  st.isHost
                      ? 'Putar lagu dari mana saja — semua anggota akan mengikutimu.'
                      : 'Menunggu host memutar lagu…',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.ink3),
                )
              else
                Row(
                  children: [
                    CoverImage(p.track.cover, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.track.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w800, color: T.ink)),
                          const SizedBox(height: 2),
                          Text(p.track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600, color: T.ink3)),
                        ],
                      ),
                    ),
                  ],
                ),
              if (!st.isHost) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(AppIcons.lock, size: 14, color: T.ink3),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        st.hostOnline
                            ? 'Kontrol pemutar dikunci — kamu mengikuti host.'
                            : 'Host sedang terputus. Menunggu host kembali…',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: T.ink3),
                      ),
                    ),
                  ],
                ),
                if (p != null) ...[
                  const SizedBox(height: 12),
                  SecondaryButton(
                      label: 'Ikut lagi', onPressed: () => ref.read(roomProvider.notifier).resync()),
                ],
              ],
            ],
          ),
        ),
        if (st.isHost) ...[
          const SizedBox(height: 14),
          _HostTools(code: st.code, name: st.name, visibility: st.visibility),
        ],
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Anggota (${st.members.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
              const SizedBox(height: 8),
              for (final m in st.members)
                _MemberRow(
                  member: m,
                  me: m.pid == st.myPid,
                  canManage: st.isHost && m.pid != st.myPid && !m.host,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SecondaryButton(
            label: st.isHost ? 'Tutup room' : 'Keluar dari room',
            danger: true,
            onPressed: () => _leave(context, ref)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {this.strong = false});
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: strong ? T.accent : T.accentSoft,
          borderRadius: BorderRadius.circular(T.rPill),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: strong ? Colors.white : T.accent2)),
      );
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member, required this.me, required this.canManage});
  final RoomMember member;
  final bool me;
  final bool canManage;

  /// Lapor/blokir hanya untuk anggota lain yang punya akun.
  bool get _canModerate => !me && member.uid > 0;

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final ctrl = ref.read(roomProvider.notifier);
    Future<void> run(Future<String?> Function() f) async {
      nav.pop();
      final err = await f();
      if (context.mounted && err != null) showToast(context, err);
    }

    await showGlassSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(name: member.name, path: member.avatar, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: T.ink)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (canManage) ...[
            SheetItem(
                icon: AppIcons.host,
                label: 'Jadikan host',
                onTap: () => run(() => ctrl.transfer(member.pid))),
            SheetItem(
                icon: AppIcons.userRemove,
                label: 'Keluarkan',
                onTap: () => run(() => ctrl.kick(member.pid))),
            SheetItem(
                icon: AppIcons.block,
                label: 'Blokir dari room',
                danger: true,
                onTap: () => run(() => ctrl.kick(member.pid, ban: true))),
          ],
          if (_canModerate) ...[
            SheetItem(
                icon: AppIcons.flag,
                label: 'Laporkan pengguna',
                onTap: () {
                  nav.pop();
                  showReportSheet(
                    context,
                    send: (reason) =>
                        ref.read(moderationServiceProvider).reportUser(member.uid, reason),
                  );
                }),
            SheetItem(
                icon: AppIcons.block,
                label: 'Blokir pengguna (sembunyikan chat)',
                danger: true,
                onTap: () async {
                  nav.pop();
                  final err =
                      await ref.read(blockedProvider.notifier).block(member.uid, member.name);
                  if (context.mounted) showToast(context, err ?? '${member.name} diblokir');
                }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (canManage || _canModerate) ? () => _manage(context, ref) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(name: member.name, path: member.avatar, size: 42),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: member.online ? _green : T.ink4,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700, color: T.ink)),
                  ),
                  if (member.host) const _Badge('Host', strong: true),
                  if (me) const _Badge('Kamu'),
                  if (member.guest && !me) const _Badge('Tamu'),
                ],
              ),
            ),
            if (canManage || _canModerate) const Icon(AppIcons.more, size: 20, color: T.ink4),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Alat host ─────────────────────────────

class _HostTools extends ConsumerWidget {
  const _HostTools({required this.code, required this.name, required this.visibility});
  final String code;
  final String name;
  final String visibility;

  Future<void> _settings(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<(String, String)>(
      context: context,
      barrierColor: T.scrim,
      builder: (_) => _SettingsDialog(name: name, visibility: visibility),
    );
    if (res == null) return;
    final err = await ref.read(roomProvider.notifier).updateSettings(name: res.$1, visibility: res.$2);
    if (context.mounted && err != null) showToast(context, err);
  }

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirm(context,
        title: 'Akhiri room?',
        message: 'Semua anggota akan keluar dan room ditutup.',
        action: 'Akhiri');
    if (!ok) return;
    final err = await ref.read(roomProvider.notifier).end();
    if (context.mounted && err != null) showToast(context, err);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Kontrol host',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
          const SizedBox(height: 4),
          SheetItem(
              icon: AppIcons.settings,
              label: 'Pengaturan room',
              onTap: () => _settings(context, ref)),
          SheetItem(
              icon: AppIcons.block,
              label: 'Daftar blokir',
              onTap: () => showGlassSheet(context, const _BansSheet())),
          SheetItem(
              icon: AppIcons.close,
              label: 'Akhiri room',
              danger: true,
              onTap: () => _end(context, ref)),
        ],
      ),
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.name, required this.visibility});
  final String name;
  final String visibility;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.name);
  late String _vis = widget.visibility;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: T.bg1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
      title: const Text('Pengaturan room',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            maxLength: 40,
            style: const TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600),
            decoration: _dec('Nama room'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AppChip(
                  label: 'Private',
                  active: _vis == 'private',
                  onTap: () => setState(() => _vis = 'private')),
              const SizedBox(width: 8),
              AppChip(
                  label: 'Public',
                  active: _vis == 'public',
                  onTap: () => setState(() => _vis = 'public')),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: T.ink3, fontWeight: FontWeight.w700))),
        TextButton(
            onPressed: () => Navigator.pop(context, (_name.text.trim(), _vis)),
            child: const Text('Simpan', style: TextStyle(color: T.accent2, fontWeight: FontWeight.w800))),
      ],
    );
  }
}

class _BansSheet extends ConsumerStatefulWidget {
  const _BansSheet();

  @override
  ConsumerState<_BansSheet> createState() => _BansSheetState();
}

class _BansSheetState extends ConsumerState<_BansSheet> {
  List<BanEntry>? _bans;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await ref.read(roomProvider.notifier).bans();
    if (mounted) setState(() => _bans = b);
  }

  Future<void> _unban(BanEntry b) async {
    final err = await ref.read(roomProvider.notifier).unban(b.id);
    if (!mounted) return;
    if (err != null) {
      showToast(context, err);
      return;
    }
    setState(() => _bans = _bans?.where((e) => e.id != b.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final bans = _bans;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Daftar blokir',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
        const SizedBox(height: 10),
        if (bans == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: T.accent)),
          )
        else if (bans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Tidak ada yang diblokir.',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink3)),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final b in bans)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(b.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w700, color: T.ink)),
                        ),
                        TextButton(
                          onPressed: () => _unban(b),
                          child: const Text('Buka blokir',
                              style: TextStyle(color: T.accent2, fontWeight: FontWeight.w800)),
                        ),
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
