import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme/tokens.dart';

/// Foto profil bulat; bila tidak ada / gagal dimuat → huruf pertama nama.
class UserAvatar extends StatefulWidget {
  const UserAvatar({super.key, required this.name, this.path, this.userId, this.size = 40});

  final String name;

  /// Path relatif (/api/auth/avatar/ID?v=VER) atau URL absolut.
  final String? path;

  /// Dipakai bila [path] kosong: coba /api/auth/avatar/<id> (404 = belum punya foto).
  final int? userId;
  final double size;

  /// Id pengguna yang diketahui belum punya foto → tidak diminta lagi (hemat request 404).
  static final Set<int> _none = <int>{};

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? get _url {
    final p = widget.path;
    if (p != null && p.isNotEmpty) return AppConfig.absUrl(p);
    final id = widget.userId;
    if (id != null && id > 0 && !UserAvatar._none.contains(id)) {
      return AppConfig.absUrl('/api/auth/avatar/$id');
    }
    return null;
  }

  Widget _initial() {
    final n = widget.name.trim();
    final letter = n.isEmpty ? '?' : String.fromCharCode(n.runes.first).toUpperCase();
    return ColoredBox(
      color: T.accentSoft,
      child: Center(
        child: Text(letter,
            style: TextStyle(
                fontSize: widget.size * 0.42, fontWeight: FontWeight.w800, color: T.accent2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: url == null
            ? _initial()
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (widget.size * 3).round(),
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => _initial(),
                errorWidget: (_, __, ___) {
                  final id = widget.userId;
                  if (id != null && (widget.path == null || widget.path!.isEmpty)) {
                    UserAvatar._none.add(id);
                  }
                  return _initial();
                },
              ),
      ),
    );
  }
}
