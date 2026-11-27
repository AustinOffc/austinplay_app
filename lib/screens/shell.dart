import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/icons.dart';
import '../core/layout.dart';
import '../core/theme/tokens.dart';
import '../providers/chat_providers.dart';
import '../providers/core_providers.dart';
import '../providers/library_providers.dart';
import '../providers/moderation_providers.dart';
import '../providers/music_providers.dart';
import '../providers/nav_providers.dart';
import '../providers/room_providers.dart';
import '../widgets/app_background.dart';
import '../widgets/app_notice.dart';
import '../widgets/glass_nav.dart';
import '../widgets/mini_player.dart';
import '../widgets/toast.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  StreamSubscription<String>? _sub;
  StreamSubscription<String>? _roomSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(libraryProvider);
    ref.read(settingsProvider);
    ref.read(blockedProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(checkAppNotice(context, ref));
    });
    _sub = ref.read(audioHandlerProvider).errors.listen((m) {
      if (mounted) showToast(context, m);
    });
    _roomSub = ref.read(roomProvider.notifier).notices.listen((m) {
      if (mounted) showToast(context, m);
    });
    ref.listenManual<AsyncValue<bool>>(onlineProvider, (prev, next) {
      final was = prev?.valueOrNull;
      final now = next.valueOrNull;
      if (now == false && was != false) {
        widget.shell.goBranch(2);
      } else if (now == true && was == false) {
        ref.read(syncServiceProvider).sync();
        ref.read(libraryProvider.notifier).backfillMissing();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ref.read(authProvider).loggedIn) ref.read(syncServiceProvider).sync();
      ref.read(chatProvider.notifier).reconnect();
    } else if (state == AppLifecycleState.paused) {
      ref.read(historyServiceProvider).pauseSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _roomSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    // Beri tahu Chat / Room tab mana yang sedang terlihat (koneksi real-time hanya saat terlihat).
    if (ref.read(tabIndexProvider) != shell.currentIndex) {
      final idx = shell.currentIndex;
      Future<void>.microtask(() {
        if (mounted) ref.read(tabIndexProvider.notifier).state = idx;
      });
    }
    final offline = ref.watch(onlineProvider).valueOrNull == false;
    final top = MediaQuery.paddingOf(context).top;
    final wide = isWideLayout(context);
    void onNav(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
    final content = Stack(
      children: [
        Positioned.fill(child: shell),
        if (offline)
          Positioned(
            top: top + 6,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: T.glass2,
                    borderRadius: BorderRadius.circular(T.rPill),
                    border: Border.all(color: T.glassEdge),
                    boxShadow: T.shadowSm,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.offline, size: 16, color: T.accent2),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text('Mode Offline — Memutar data tersimpan',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: T.ink2)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: wide
            ? Row(
                children: [
                  GlassRail(index: shell.currentIndex, onTap: onNav),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: wide
          ? const Padding(
              padding: EdgeInsets.only(left: kRailWidth),
              child: MiniPlayer(),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                GlassNav(index: shell.currentIndex, onTap: onNav),
              ],
            ),
    );
  }
}
