class AppUser {
  const AppUser({required this.id, required this.username, this.avatar});
  final int id;
  final String username;

  /// Path relatif (/api/auth/avatar/ID?v=VERSI) atau null.
  final String? avatar;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        username: (j['username'] as String?) ?? '',
        avatar: j['avatar'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username, 'avatar': avatar};
}
