import '../core/api_client.dart';

class BlockedUser {
  const BlockedUser(this.id, this.username);
  final int id;
  final String username;
}

/// Moderasi konten buatan pengguna (backend_patch/src/routes/moderation.routes.js).
class ModerationService {
  ModerationService(this._api);
  final ApiClient _api;

  static const List<(String, String)> reasons = [
    ('spam', 'Spam atau iklan'),
    ('pelecehan', 'Pelecehan atau perundungan'),
    ('sara', 'Ujaran kebencian / SARA'),
    ('seksual', 'Konten seksual'),
    ('kekerasan', 'Kekerasan atau ancaman'),
    ('lainnya', 'Lainnya'),
  ];

  Future<void> reportMessage(int messageId, String reason) async {
    await _api.post('/api/chat/report', data: {'messageId': messageId, 'reason': reason});
  }

  Future<void> reportUser(int userId, String reason) async {
    await _api.post('/api/report-user', data: {'userId': userId, 'reason': reason});
  }

  Future<List<BlockedUser>> blocked() async {
    final r = await _api.get('/api/block');
    final list = r['blocked'];
    if (list is! List) return <BlockedUser>[];
    return list.whereType<Map>().map((e) {
      final id = e['id'];
      return BlockedUser(id is num ? id.toInt() : (int.tryParse('$id') ?? 0), (e['username'] ?? '').toString());
    }).where((b) => b.id > 0).toList();
  }

  Future<void> block(int userId) async {
    await _api.post('/api/block', data: {'userId': userId});
  }

  Future<void> unblock(int userId) async {
    await _api.delete('/api/block/$userId');
  }
}
