import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/icons.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  GoRoute tab(String path, Widget Function() build) =>
      GoRoute(path: path, builder: (context, state) => build());

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [tab('/home', () => const HomeScreen())]),
          StatefulShellBranch(routes: [
            tab('/search', () => const PlaceholderScreen(title: 'Cari', icon: AppIcons.search, note: 'Pencarian lagu hadir di Tahap 2.'))
          ]),
          StatefulShellBranch(routes: [
            tab('/library', () => const PlaceholderScreen(title: 'Koleksi', icon: AppIcons.library, note: 'Playlist, favorit, dan offline hadir di Tahap 3.'))
          ]),
          StatefulShellBranch(routes: [
            tab('/room', () => const PlaceholderScreen(title: 'Room', icon: AppIcons.room, note: 'Listen Together hadir di Tahap 4.'))
          ]),
          StatefulShellBranch(routes: [
            tab('/chat', () => const PlaceholderScreen(title: 'Chat', icon: AppIcons.chat, note: 'Chat Global hadir di Tahap 4.'))
          ]),
          StatefulShellBranch(routes: [tab('/profile', () => const ProfileScreen())]),
        ],
      ),
    ],
  );
});

class AuzifyApp extends ConsumerWidget {
  const AuzifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Auzify',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
