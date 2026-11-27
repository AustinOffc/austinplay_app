import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/icons.dart';
import '../core/layout.dart';
import '../core/theme/tokens.dart';
import '../models/browse.dart';
import '../providers/music_providers.dart';
import '../widgets/browse_actions.dart';
import '../widgets/chips.dart';
import '../widgets/glass_card.dart';
import '../widgets/page_header.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Diisi saat tab Cari dibuka dari Beranda (mis. ketuk artis).
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _historyKey = 'search_history';
  static const _types = <MapEntry<String, String>>[
    MapEntry('all', 'Semua'),
    MapEntry('songs', 'Lagu'),
    MapEntry('videos', 'Video'),
    MapEntry('artists', 'Artis'),
    MapEntry('playlists', 'Playlist & album'),
  ];

  final TextEditingController _c = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _type = 'all';
  List<String> _suggestions = [];
  List<String> _history = [];
  SearchResult? _result;
  bool _loading = false;
  Object? _error;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _loadHistory();
    _applyInitial();
  }

  @override
  void didUpdateWidget(covariant SearchScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialQuery != old.initialQuery) _applyInitial();
  }

  void _applyInitial() {
    final q = widget.initialQuery;
    if (q != null && q.trim().isNotEmpty) {
      _c.text = q;
      _type = 'all';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submit(q);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_historyKey);
      if (s != null) {
        final l = jsonDecode(s);
        if (l is List && mounted) setState(() => _history = l.map((e) => e.toString()).toList());
      }
    } catch (_) {}
  }

  Future<void> _saveHistory(String q) async {
    final l = [q, ..._history.where((e) => e.toLowerCase() != q.toLowerCase())].take(10).toList();
    setState(() => _history = l);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_historyKey, jsonEncode(l));
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_historyKey);
    } catch (_) {}
  }

  void _onChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      try {
        final s = await ref.read(musicServiceProvider).suggest(q);
        if (mounted && _c.text.trim() == q) setState(() => _suggestions = s.take(8).toList());
      } catch (_) {}
    });
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    _c.text = q;
    _focus.unfocus();
    final my = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = [];
    });
    _saveHistory(q);
    try {
      final r = await ref.read(musicServiceProvider).search(q, type: _type);
      if (!mounted || my != _seq) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || my != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _clear() {
    _seq++;
    _c.clear();
    setState(() {
      _result = null;
      _error = null;
      _loading = false;
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPlayer = ref.watch(hasPlayerProvider);
    return Column(
      children: [
        const PageHeader(title: 'Cari'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, .78),
              borderRadius: BorderRadius.circular(T.rPill),
              border: Border.all(color: _focus.hasFocus ? T.accent : T.line),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.search, size: 20, color: T.ink3),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _c,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: _submit,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: T.ink),
                    cursorColor: T.accent,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Cari lagu, artis, atau tempel link YouTube',
                      hintStyle: TextStyle(fontSize: 14.5, color: T.ink4, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                if (_c.text.isNotEmpty)
                  GestureDetector(
                    onTap: _clear,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(AppIcons.close, size: 20, color: T.ink3),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            children: [
              for (final t in _types)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(
                    label: t.value,
                    active: _type == t.key,
                    onTap: () {
                      if (_type == t.key) return;
                      setState(() => _type = t.key);
                      if (_c.text.trim().isNotEmpty) _submit(_c.text);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _body(hasPlayer)),
      ],
    );
  }

  Widget _body(bool hasPlayer) {
    final pad = EdgeInsets.fromLTRB(16, 4, 16, contentBottomPad(context, withPlayer: hasPlayer));

    // Saran ketik
    if (_focus.hasFocus && _c.text.trim().isNotEmpty && _suggestions.isNotEmpty) {
      return ListView(
        padding: pad,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          for (final s in _suggestions)
            _SimpleRow(icon: AppIcons.search, text: s, onTap: () => _submit(s)),
        ],
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: T.accent, strokeWidth: 3));
    }

    if (_error != null) {
      return ListView(padding: pad, children: [
        GlassCard(
          child: Text(ApiClient.messageOf(_error!),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: T.ink2)),
        ),
      ]);
    }

    final r = _result;
    if (r == null) {
      // Riwayat pencarian
      if (_history.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Cari lagu, artis, atau tempel link YouTube.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: T.ink3)),
          ),
        );
      }
      return ListView(
        padding: pad,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Pencarian terakhir',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: const Text('Hapus',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: T.accent2)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final h in _history) _SimpleRow(icon: AppIcons.history, text: h, onTap: () => _submit(h)),
        ],
      );
    }

    if (r.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Tidak ada hasil. Coba kata kunci lain.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: T.ink3)),
        ),
      );
    }

    final handler = ref.read(audioHandlerProvider);
    final showSongs = _type == 'all' || _type == 'songs' || _type == 'videos';
    final showArtists = _type == 'all' || _type == 'artists';
    final showLists = _type == 'all' || _type == 'playlists';
    final lists = r.playlistsAndAlbums;

    return ListView(
      padding: pad,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (showSongs && r.songs.isNotEmpty) ...[
          const _Title('Lagu'),
          for (var i = 0; i < r.songs.length; i++)
            TrackTile(track: r.songs[i], onTap: () => handler.playQueue(r.songs, i)),
        ],
        if (showArtists && r.artists.isNotEmpty) ...[
          const _Title('Artis'),
          for (final a in r.artists.take(_type == 'all' ? 4 : 20))
            BrowseRow(item: a, onTap: () => openBrowseItem(context, ref, a)),
        ],
        if (showLists && lists.isNotEmpty) ...[
          const _Title('Playlist & album'),
          for (final p in lists.take(_type == 'all' ? 6 : 30))
            BrowseRow(item: p, onTap: () => openBrowseItem(context, ref, p)),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 0, 10),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
      );
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            children: [
              Icon(icon, size: 20, color: T.ink3),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: T.ink2)),
              ),
              const Icon(AppIcons.arrowUpLeft, size: 18, color: T.ink4),
            ],
          ),
        ),
      );
}
