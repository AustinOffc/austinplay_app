import 'package:flutter/material.dart';
import '../core/theme/tokens.dart';

/// Chip kategori: tidak aktif = glass + tepi; aktif = accent + teks putih bobot 700.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: T.dur,
        curve: T.ease,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? T.accent : T.glass,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: active ? T.accent : T.glassEdge),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : T.ink2,
          ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.size = 40});
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: T.glass2,
          border: Border.all(color: T.glassEdge),
          boxShadow: T.shadowSm,
        ),
        child: Icon(icon, size: 20, color: T.ink2),
      ),
    );
  }
}
