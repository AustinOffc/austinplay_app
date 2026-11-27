import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../services/moderation_service.dart';
import 'core_providers.dart';

final moderationServiceProvider =
    Provider<ModerationService>((ref) => ModerationService(ref.watch(apiClientProvider)));

/// Daftar pengguna yang diblokir (dimuat dari server saat login).
class BlockedController extends Notifier<List<BlockedUser>> {
  @override
  List<BlockedUser> build() {
    ref.listen<bool>(authProvider.select((s) => s.loggedIn), (_, next) {
      if (next) {
        unawaited(load());
      } else {
        state = const <BlockedUser>[];
      }
    });
    if (ref.read(authProvider).loggedIn) Future<void>.microtask(load);
    return const <BlockedUser>[];
  }

  Future<void> load() async {
    try {
      state = await ref.read(moderationServiceProvider).blocked();
    } catch (_) {
      // dicoba lagi saat dibuka berikutnya
    }
  }

  /// Mengembalikan pesan error, atau null bila sukses.
  Future<String?> block(int userId, String username) async {
    try {
      await ref.read(moderationServiceProvider).block(userId);
      if (!state.any((b) => b.id == userId)) {
        state = [BlockedUser(userId, username), ...state];
      }
      return null;
    } catch (e) {
      return ApiClient.messageOf(e);
    }
  }

  Future<String?> unblock(int userId) async {
    try {
      await ref.read(moderationServiceProvider).unblock(userId);
      state = state.where((b) => b.id != userId).toList();
      return null;
    } catch (e) {
      return ApiClient.messageOf(e);
    }
  }
}

final blockedProvider =
    NotifierProvider<BlockedController, List<BlockedUser>>(BlockedController.new);

final blockedIdsProvider =
    Provider<Set<int>>((ref) => ref.watch(blockedProvider).map((b) => b.id).toSet());
