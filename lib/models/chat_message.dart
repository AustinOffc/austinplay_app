int _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Pesan Chat Global. Bentuk server: {id, uid, u (username), t (teks), ts (ms)}.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.uid,
    required this.username,
    required this.text,
    required this.ts,
  });

  final int id;
  final int uid;
  final String username;
  final String text;
  final int ts;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _int(j['id']),
        uid: _int(j['uid']),
        username: (j['u'] ?? '').toString(),
        text: (j['t'] ?? '').toString(),
        ts: _int(j['ts']),
      );
}

/// Balasan GET /api/chat/messages.
class ChatPage {
  const ChatPage({
    required this.messages,
    required this.hasMore,
    required this.online,
    required this.meId,
    required this.admin,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final int online;
  final int meId;
  final bool admin;
}
