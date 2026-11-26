class AppUser {
  const AppUser({required this.id, required this.username, this.avatar});
  final int id;
  final String username;

  /// Path relatif (/api/auth/avatar/ID?v=VERSI) atau null.
  final String? avatar;

  /// Server memakai BIGSERIAL, jadi id bisa datang sebagai angka ATAU string.
  static int _toInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _toInt(j['id']),
        username: (j['username'] as String?) ?? '',
        avatar: j['avatar'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username, 'avatar': avatar};
}
