import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/browse.dart';

/// Artis → halaman Artis (bila id ada, kalau tidak Cari). Playlist/album → halaman Album.
Future<void> openBrowseItem(BuildContext context, WidgetRef ref, BrowseItem item) async {
  if (item.kind == BrowseKind.artist) {
    if (item.id.isNotEmpty) {
      context.push('/artist/${Uri.encodeComponent(item.id)}');
    } else {
      context.go('/search?q=${Uri.encodeQueryComponent(item.title)}');
    }
    return;
  }
  context.push('/album/${Uri.encodeComponent(item.id)}');
}
