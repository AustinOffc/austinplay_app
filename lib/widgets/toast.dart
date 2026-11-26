import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/tokens.dart';

/// Toast pill di atas tengah (fade + slide 300 ms, tampil 3,2 dtk).
void showToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _ToastView(message: message, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.onDone});
  final String message;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _t = Timer(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 12;
    final curved = CurvedAnimation(parent: _c, curve: T.ease);
    return Positioned(
      top: top,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(curved),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: T.glass2,
                    borderRadius: BorderRadius.circular(T.rPill),
                    border: Border.all(color: T.glassEdge),
                    boxShadow: T.shadowSm,
                  ),
                  child: Text(widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: T.ink, fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
