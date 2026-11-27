import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/api_client.dart';
import 'core/local_store.dart';
import 'core/storage.dart';
import 'providers/core_providers.dart';
import 'providers/library_providers.dart';
import 'providers/music_providers.dart';
import 'services/audio_handler.dart';
import 'services/download_service.dart';
import 'services/history_service.dart';
import 'services/lyrics_cache.dart';
import 'services/music_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Satu instance dipakai bersama oleh UI dan mesin audio (token yang sama).
  final tokens = TokenStore();
  await tokens.load();
  final api = ApiClient(tokens);
  final music = MusicService(api);
  final store = await LocalStore.open();
  final history = HistoryService(store);
  final downloads = DownloadService(api, music);
  await downloads.init();
  final lyricsCache = LyricsCache();
  await lyricsCache.init();
  lyricsCache.wants = downloads.has;
  music.lyricsCache = lyricsCache;
  downloads.lyricsCache = lyricsCache;
  final sync = SyncService(api, store, tokens);
  final handler = await AudioService.init<AuzifyAudioHandler>(
    builder: () => AuzifyAudioHandler(music),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'id.austin.auzify.audio',
      androidNotificationChannelName: 'Pemutar Auzify',
      androidNotificationOngoing: true,
    ),
  );

  handler.history = history;
  handler.localPath = downloads.pathOf;

  runApp(ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(api),
      musicServiceProvider.overrideWithValue(music),
      audioHandlerProvider.overrideWithValue(handler),
      localStoreProvider.overrideWithValue(store),
      historyServiceProvider.overrideWithValue(history),
      downloadServiceProvider.overrideWithValue(downloads),
      syncServiceProvider.overrideWithValue(sync),
    ],
    child: const AuzifyApp(),
  ));
}
