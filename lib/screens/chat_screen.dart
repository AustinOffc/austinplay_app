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
import '../providers/music_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/moderation_sheets.dart';
import '../widgets/page_header.dart';
import '../widgets/toast.dart';
import '../widgets/track_actions.dart';
import '../widgets/user_avatar.dart';

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
    return Column(
      children: [
        PageHeader(
          title: 'Chat',
          trailing: loggedIn && st.connected
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: T.glass2,
                    borderRadius: BorderRadius.circular(T.rPill),
                    border: Border.all(color: T.glassEdge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3DBE7A)),
                      ),
                      const SizedBox(width: 6),
                      Text('${st.online} online',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: T.ink2)),
                    ],
                  ),
                )
              : null,
        ),
        Expanded(child: loggedIn ? _body(context, st) : _loginPrompt(context)),
      ],
    );
  }

  Widget _loginPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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

  Widget _body(BuildContext context, ChatState st) {
    final hasPlayer = ref.watch(hasPlayerProvider);
    final view = View.of(context);
    final keyboardOpen = view.viewInsets.bottom > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final navPad = keyboardOpen ? 8.0 : (66 + 10 + safeBottom + (hasPlayer ? 76 : 0) + 8);
    final blocked = ref.watch(blockedIdsProvider);
    final msgs = st.messages.where((m) => !blocked.contains(m.uid)).toList();
    final count = msgs.length + (st.hasMore ? 1 : 0);

    Widget list;
    if (st.loading && msgs.isEmpty) {
      list = const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: T.accent));
    } else if (msgs.isEmpty) {
      list = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            st.error.isNotEmpty ? st.error : 'Belum ada pesan. Sapa yang lain!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink3),
          ),
        ),
      );
    } else {
      list = ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        itemCount: count,
        itemBuilder: (_, i) {
          if (i >= msgs.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(chatProvider.notifier).loadOlder();
            });
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: T.accent),
                ),
              ),
            );
          }
          final m = msgs[msgs.length - 1 - i];
          return _Bubble(
            key: ValueKey<int>(m.id),
            msg: m,
            mine: m.uid == st.meId,
            onLongPress: () => _onLongPress(m, st),
          );
        },
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Pesan dihapus otomatis setelah 7 hari. Tahan pesan untuk melapor/memblokir. Dilarang spam, pelecehan, dan SARA.',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: T.ink4)),
        ),
        if (!st.connected && msgs.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Menyambungkan ulang…',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: T.accent2)),
          ),
        Expanded(child: list),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 6, 12, navPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  style: const TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan…',
                    hintStyle: const TextStyle(color: T.ink4, fontWeight: FontWeight.w500),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, .78),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: T.line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: T.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: T.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sending ? T.accentTint : T.accent,
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(AppIcons.send, size: 22, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _hhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.msg, required this.mine, required this.onLongPress});
  final ChatMessage msg;
  final bool mine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.74;
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? T.accent : T.glass2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 5),
            bottomRight: Radius.circular(mine ? 5 : 18),
          ),
          border: mine ? null : Border.all(color: T.glassEdge),
          boxShadow: mine ? null : T.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(msg.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: T.accent2)),
              ),
            Text(msg.text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: mine ? Colors.white : T.ink)),
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_hhmm(msg.ts),
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: mine ? const Color.fromRGBO(255, 255, 255, .8) : T.ink4)),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            UserAvatar(name: msg.username, userId: msg.uid, size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
