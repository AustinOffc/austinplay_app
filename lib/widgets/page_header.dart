import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../core/theme/tokens.dart';

/// Header halaman kaca (judul 1.55rem ≈ 25 px, bobot 800).
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, top + 12, 18, 12),
          decoration: const BoxDecoration(
            color: T.glass2,
            border: Border(bottom: BorderSide(color: T.glassEdge)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: T.ink)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
