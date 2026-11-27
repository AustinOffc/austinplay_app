import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/core_providers.dart';
import 'providers/nav_providers.dart';
import 'screens/album_screen.dart';
import 'screens/artist_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/play_link_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/room_screen.dart';
import 'screens/search_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'screens/stats_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  GoRoute tab(String path, Widget Function() build) =>
      GoRoute(path: path, builder: (context, state) => build());

  return GoRouter(
    initialLocation: '/splash',
    // Tautan yang masuk saat app belum siap (cold start) ditahan dulu, lalu dibuka setelah splash.
    redirect: (context, state) {
      final uri = state.uri;
      if (!ref.read(authProvider).ready && uri.path != '/splash') {
        DeepLinks.pending = uri.toString();
        return '/splash';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      // https://domain/?together=KODE → tab Room (gabung otomatis); selain itu ke Beranda.
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final code = state.uri.queryParameters['together'];
          if (code != null && code.isNotEmpty) {
            final c = code.toUpperCase();
            Future<void>.microtask(() => ref.read(pendingJoinProvider.notifier).state = c);
            return '/room';
          }
          return '/home';
        },
      ),
      GoRoute(
        path: '/play/:id',
        builder: (context, state) => PlayLinkScreen(
          id: state.pathParameters['id'] ?? '',
          title: state.uri.queryParameters['title'],
          artist: state.uri.queryParameters['artist'],
          cover: state.uri.queryParameters['cover'] ?? state.uri.queryParameters['thumb'],
        ),
      ),
      GoRoute(
        path: '/artist/:id',
        builder: (context, state) => ArtistScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/album/:id',
        builder: (context, state) => AlbumScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/playlist/:id',
        builder: (context, state) => PlaylistScreen(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [tab('/home', () => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => SearchScreen(initialQuery: state.uri.queryParameters['q']),
            )
          ]),
          StatefulShellBranch(routes: [tab('/library', () => const LibraryScreen())]),
          StatefulShellBranch(routes: [tab('/room', () => const RoomScreen())]),
          StatefulShellBranch(routes: [tab('/chat', () => const ChatScreen())]),
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
