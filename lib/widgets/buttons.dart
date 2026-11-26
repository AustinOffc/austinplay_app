import 'package:flutter/material.dart';
import '../core/theme/tokens.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: T.dur,
        curve: T.ease,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? T.accent : T.accentTint,
          borderRadius: BorderRadius.circular(T.rPill),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.danger = false});
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: T.glass2,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: T.glassEdge),
        ),
        child: Text(label,
            style: TextStyle(
                color: danger ? T.danger : T.ink2, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}
