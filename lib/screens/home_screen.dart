import 'package:flutter/material.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../widgets/glass_card.dart';

/// Beranda sementara (Tahap 2 akan mengisi seksi sesuai web).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 66 + 10 + MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/images/auzify-icon-512.png', width: 36, height: 36),
            ),
            const SizedBox(width: 10),
            const Text('Auzify',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: T.ink)),
          ],
        ),
        const SizedBox(height: 18),
        const GlassCard(
          strong: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.home, color: T.accent2),
              SizedBox(height: 10),
              Text('Beranda segera hadir',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: T.ink)),
              SizedBox(height: 6),
              Text('Fondasi aplikasi sudah siap: tema, navigasi, dan akun. Pemutar, pencarian, dan lirik dikerjakan di Tahap 2.',
                  style: TextStyle(fontSize: 13, color: T.ink2, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
