import 'package:flutter/material.dart';
import '../core/theme/tokens.dart';

/// Latar halaman: gradasi 160° + dua lingkaran datar (tanpa blur/animasi).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.34, -1),
                end: Alignment(0.34, 1),
                colors: [T.bg1, T.bg2, T.bg3],
                stops: [0, 0.46, 1],
              ),
            ),
          ),
        ),
        Positioned(
          right: -w * 0.25,
          top: -w * 0.25,
          child: Container(
            width: w * 0.78,
            height: w * 0.78,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromRGBO(255, 255, 255, .34),
            ),
          ),
        ),
        Positioned(
          left: -w * 0.22,
          bottom: -w * 0.22,
          child: Container(
            width: w * 0.64,
            height: w * 0.64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromRGBO(246, 170, 198, .20),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
