import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../core/theme/tokens.dart';
import '../models/user.dart';
import '../providers/core_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/page_header.dart';
import '../widgets/toast.dart';
import 'auth_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    final bottomPad = 66 + 10 + MediaQuery.paddingOf(context).bottom + 24;
    return Column(
      children: [
        const PageHeader(title: 'Profil'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
            children: [
              if (user == null) const AuthCard() else _AccountCard(user: user),
              const SizedBox(height: 14),
              const GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tentang',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: T.ink)),
                    SizedBox(height: 8),
                    Text('Auzify v${AppConfig.appVersion} (web ${AppConfig.webVersion})',
                        style: TextStyle(fontSize: 13, color: T.ink2, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('Auzify tidak berafiliasi dengan YouTube atau Google.',
                        style: TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.user});
  final AppUser user;

  Future<void> _logoutAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari semua perangkat?'),
        content: const Text('Semua perangkat lain (termasuk web) akan keluar dari akunmu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar', style: TextStyle(color: T.danger))),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(authProvider.notifier).signOutAll();
    if (context.mounted && err != null) showToast(context, err);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = AppConfig.absUrl(user.avatar);
    final initial = user.username.isEmpty ? '?' : user.username.substring(0, 1).toUpperCase();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _Initial(initial),
                        )
                      : _Initial(initial),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: T.ink)),
                    const SizedBox(height: 2),
                    const Text('Akun tersambung',
                        style: TextStyle(fontSize: 12, color: T.ink3, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SecondaryButton(
              label: 'Keluar', onPressed: () => ref.read(authProvider.notifier).signOut()),
          const SizedBox(height: 8),
          SecondaryButton(
              label: 'Keluar dari semua perangkat',
              danger: true,
              onPressed: () => _logoutAll(context, ref)),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial(this.letter);
  final String letter;
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: T.accentSoft,
        child: Center(
          child: Text(letter,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: T.accent2)),
        ),
      );
}
