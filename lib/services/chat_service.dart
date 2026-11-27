import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/sse.dart';
import '../models/chat_message.dart';

/// Chat Global (src/routes/chat.routes.js). Semua endpoint wajib login.
class ChatService {
  ChatService(this._api);
  final ApiClient _api;

  Future<ChatPage> messages({int limit = 40, int? before, int? after}) async {
    final r = await _api.get('/api/chat/messages', query: {
      'limit': limit,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    });
    final list = r['messages'];
    final me = r['me'] is Map ? Map<String, dynamic>.from(r['me'] as Map) : <String, dynamic>{};
    final meId = me['id'];
    return ChatPage(
      messages: list is List
          ? list
              .whereType<Map>()
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <ChatMessage>[],
      hasMore: r['hasMore'] == true,
      online: r['online'] is num ? (r['online'] as num).toInt() : 0,
      meId: meId is num ? meId.toInt() : (int.tryParse('$meId') ?? 0),
      admin: me['admin'] == true,
    );
  }

  Future<ChatMessage> send(String text) async {
    final r = await _api.post('/api/chat/messages', data: {'text': text});
    final m = r['message'];
    if (m is! Map) throw ApiException('Balasan server tidak dikenali.');
    return ChatMessage.fromJson(Map<String, dynamic>.from(m));
  }

  Future<void> delete(int id) async {
    await _api.delete('/api/chat/messages/$id');
  }

  /// Event: hello, msg, del, presence.
  Stream<SseEvent> events(CancelToken cancel) =>
      openSse(_api.dio, '/api/chat/events', cancel: cancel);
}
