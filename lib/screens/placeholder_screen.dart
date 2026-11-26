import 'package:flutter/material.dart';
import '../core/theme/tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/page_header.dart';

/// Layar sementara untuk tab yang dikerjakan di tahap berikutnya.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon, required this.note});
  final String title;
  final IconData icon;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(title: title),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 36, color: T.accent2),
                    const SizedBox(height: 12),
                    Text(note,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: T.ink2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
