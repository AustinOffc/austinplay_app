import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../providers/core_providers.dart';
import '../providers/moderation_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/moderation_sheets.dart';
import '../widgets/toast.dart';
import '../widgets/track_actions.dart';

/// Chat Global (wajib login). Pesan dihapus otomatis server setelah 7 hari.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(chatProvider.notifier).refreshActive();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    final err = await ref.read(chatProvider.notifier).send(t);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err != null) {
      showToast(context, err);
    } else {
      _text.clear();
    }
  }

  Future<void> _onLongPress(ChatMessage m, ChatState st) async {
    final mine = m.uid == st.meId;
    final canDelete = mine || st.admin;
    final nav = Navigator.of(context, rootNavigator: true);
    await showGlassSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetItem(
            icon: AppIcons.copy,
            label: 'Salin pesan',
            onTap: () {
              Clipboard.setData(ClipboardData(text: m.text));
              nav.pop();
              if (mounted) showToast(context, 'Pesan disalin');
            },
          ),
          if (!mine) ...[
            SheetItem(
              icon: AppIcons.flag,
              label: 'Laporkan pesan',
              onTap: () {
                nav.pop();
                showReportSheet(
                  context,
                  send: (reason) =>
                      ref.read(moderationServiceProvider).reportMessage(m.id, reason),
                );
              },
            ),
            SheetItem(
              icon: AppIcons.block,
              label: 'Blokir ${m.username}',
              danger: true,
              onTap: () async {
                nav.pop();
                final ok = await showConfirm(context,
                    title: 'Blokir ${m.username}?',
                    message: 'Pesan dari pengguna ini akan disembunyikan di perangkatmu.',
                    action: 'Blokir');
                if (!ok || !mounted) return;
                final err = await ref.read(blockedProvider.notifier).block(m.uid, m.username);
                if (mounted) showToast(context, err ?? '${m.username} diblokir');
              },
            ),
          ],
          if (canDelete)
            SheetItem(
              icon: AppIcons.trash,
              label: 'Hapus pesan',
              danger: true,
              onTap: () async {
                nav.pop();
                final err = await ref.read(chatProvider.notifier).remove(m.id);
                if (mounted && err != null) showToast(context, err);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider.select((s) => s.loggedIn));
    final st = ref.watch(chatProvider);
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header persis seperti web: judul + subjudul di kiri, pill status di kanan.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chat Global',
                          style: TextStyle(
                              fontSize: 22,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: T.ink)),
                      SizedBox(height: 2),
                      Text('Pesan otomatis terhapus setelah 7 hari',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: T.ink3)),
                    ],
                  ),
                ),
                if (loggedIn) ...[
                  const SizedBox(width: 10),
                  _StatusPill(connected: st.connected, online: st.online),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: loggedIn ? _body(context, st) : _loginPrompt(context)),
        ],
      ),
    );
  }

  Widget _loginPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(AppIcons.chat, size: 36, color: T.accent2),
              const SizedBox(height: 12),
              const Text('Masuk untuk ikut Chat Global',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
              const SizedBox(height: 6),
              const Text('Ngobrol dengan pendengar Auzify lainnya secara real-time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: T.ink3)),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Masuk atau daftar', onPressed: () => context.go('/profile')),
            ],
          ),
        ),
      ),
    );
  }

  /// Susun pesan (urut lama → baru) + pemisah hari + penanda "satu pengirim beruntun".
  List<_Entry> _entries(List<ChatMessage> msgs) {
    final out = <_Entry>[];
    ChatMessage? prev;
    for (final m in msgs) {
      final sameDay = prev != null && _sameDay(prev.ts, m.ts);
      if (prev == null || !sameDay) out.add(_Entry.day(_dayLabel(m.ts)));
      final grouped = prev != null && sameDay && prev.uid == m.uid && (m.ts - prev.ts) < 5 * 60000;
      out.add(_Entry.msg(m, grouped));
      prev = m;
    }
    return out;
  }

  Widget _body(BuildContext context, ChatState st) {
    final mq = MediaQuery.of(context);
    final keyboardOpen = mq.viewInsets.bottom > 0;
    // Scaffold shell memakai extendBody: padding.bottom SUDAH berisi tinggi nav + mini player + safe area.
    // Jangan ditambah lagi (itu penyebab celah besar di atas kolom tulis pesan).
    final bottomPad = keyboardOpen ? 8.0 : mq.padding.bottom + 10;
    final blocked = ref.watch(blockedIdsProvider);
    final msgs = st.messages.where((m) => !blocked.contains(m.uid)).toList();
    final entries = _entries(msgs);

    Widget list;
    if (st.loading && msgs.isEmpty) {
      list = const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: T.accent));
    } else if (msgs.isEmpty) {
      list = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            st.error.isNotEmpty ? st.error : 'Belum ada pesan. Jadilah yang pertama menyapa 👋',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: T.ink3),
          ),
        ),
      );
    } else {
      list = LayoutBuilder(
        builder: (context, box) {
          final maxW = box.maxWidth * 0.82;
          return ListView.builder(
            controller: _scroll,
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length + 1,
            itemBuilder: (_, i) {
              // Item terakhir (paling atas) = pemuat pesan lama atau catatan aturan.
              if (i >= entries.length) {
                if (st.hasMore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) ref.read(chatProvider.notifier).loadOlder();
                  });
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: T.accent),
                      ),
                    ),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    'Tahan pesan untuk menyalin, melapor, atau memblokir. Dilarang spam, pelecehan, dan SARA.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: T.ink4),
                  ),
                );
              }
              final e = entries[entries.length - 1 - i];
              if (e.day != null) return _DayChip(label: e.day!);
              final m = e.msg!;
              return _Bubble(
                key: ValueKey<int>(m.id),
                msg: m,
                mine: m.uid == st.meId,
                grouped: e.grouped,
                maxWidth: maxW,
                onLongPress: () => _onLongPress(m, st),
              );
            },
          );
        },
      );
    }

    return Column(
      children: [
        if (!st.connected && msgs.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Menyambungkan ulang…',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: T.accent2)),
          ),
        // Kotak kaca pembungkus daftar pesan (sama seperti .chat-list di web).
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: T.glass3,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: T.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: list,
          ),
        ),
        const SizedBox(height: 8),
        _compose(),
        Padding(
          padding: EdgeInsets.only(top: 4, bottom: bottomPad),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (_, v, __) => SizedBox(
              height: 12,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(v.text.length > 400 ? '${v.text.length}/500' : '',
                      style: const TextStyle(fontSize: 10.5, color: T.ink3)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _compose() {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: c));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
            style: const TextStyle(fontSize: 16, height: 1.3, color: T.ink, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tulis pesan…',
              hintStyle: const TextStyle(color: T.ink4, fontWeight: FontWeight.w500),
              filled: true,
              fillColor: T.glass2,
              constraints: const BoxConstraints(minHeight: 44),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              border: border(T.line),
              enabledBorder: border(T.line),
              focusedBorder: border(T.accent),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          builder: (_, v, __) {
            final enabled = v.text.trim().isNotEmpty && !_sending;
            return GestureDetector(
              onTap: enabled ? _send : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _sending ? .7 : (enabled ? 1.0 : .4),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: T.accent),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(AppIcons.sendOutline, size: 20, color: Colors.white),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

class _Entry {
  const _Entry.day(String label)
      : day = label,
        msg = null,
        grouped = false;
  const _Entry.msg(ChatMessage m, this.grouped)
      : msg = m,
        day = null;
  final String? day;
  final ChatMessage? msg;
  final bool grouped;
}

String _hhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

bool _sameDay(int a, int b) {
  final x = DateTime.fromMillisecondsSinceEpoch(a);
  final y = DateTime.fromMillisecondsSinceEpoch(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];

String _dayLabel(int ms) {
  final now = DateTime.now();
  if (_sameDay(ms, now.millisecondsSinceEpoch)) return 'Hari ini';
  if (_sameDay(ms, now.subtract(const Duration(days: 1)).millisecondsSinceEpoch)) return 'Kemarin';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]}';
}

/// Warna nama pengirim per user — rumus sama dengan web: hsl(hue, 55%, 38%).
Color _nameColor(String name) {
  var h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) % 360;
  }
  return HSLColor.fromAHSL(1, h.toDouble(), .55, .38).toColor();
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected, required this.online});
  final bool connected;
  final int online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: T.glass2,
        borderRadius: BorderRadius.circular(T.rPill),
        border: Border.all(color: T.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? const Color(0xFF2FB96B) : const Color(0xFFB9A3AE)),
          ),
          const SizedBox(width: 6),
          Text(connected ? '${online < 1 ? 1 : online} online' : 'Menyambung…',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: T.ink2)),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: T.glass2, borderRadius: BorderRadius.circular(T.rPill)),
          child: Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: T.ink3)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.msg,
    required this.mine,
    required this.grouped,
    required this.maxWidth,
    required this.onLongPress,
  });
  final ChatMessage msg;
  final bool mine;
  final bool grouped;
  final double maxWidth;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : T.ink;
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 5),
        decoration: BoxDecoration(
          color: mine ? T.accent : T.glass2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 5),
            bottomRight: Radius.circular(mine ? 5 : 16),
          ),
          border: mine ? null : Border.all(color: T.line),
          boxShadow: mine ? null : T.shadowSm,
        ),
        // IntrinsicWidth: gelembung membungkus isi (tidak melebar penuh karena Align jam).
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!mine && !grouped)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(msg.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: _nameColor(msg.username))),
                ),
              Text(msg.text,
                  style: TextStyle(fontSize: 14.5, height: 1.38, fontWeight: FontWeight.w500, color: fg)),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: Text(_hhmm(msg.ts),
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w500, color: fg.withAlpha(184))),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(6, grouped ? 1.5 : 4.5, 6, grouped ? 1.5 : 4.5),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [Flexible(child: bubble)],
      ),
    );
  }
}
