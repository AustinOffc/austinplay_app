import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../core/theme/tokens.dart';

/// Kartu kaca (Soft Pink Glass + kilau Liquid Glass). Batasi jumlah [blur] aktif per layar:
/// untuk item list panjang set blur:false (fill + sheen saja).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = T.rLg,
    this.strong = false,
    this.blur = true,
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool strong;
  final bool blur;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: strong ? T.glass2 : T.glass,
        borderRadius: r,
        border: Border.all(color: T.glassEdge),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: const RadialGradient(
                    center: Alignment(-0.85, -0.95),
                    radius: 1.0,
                    colors: [
                      Color.fromRGBO(255, 255, 255, .36),
                      Color.fromRGBO(255, 255, 255, .08),
                      Color.fromRGBO(255, 255, 255, 0),
                    ],
                    stops: [0, .45, 1],
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    body = ClipRRect(
      borderRadius: r,
      child: blur
          ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: body)
          : body,
    );

    body = DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadow ? T.shadow : null),
      child: body,
    );

    if (onTap == null) return body;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body);
  }
}
