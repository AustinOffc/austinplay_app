import 'package:flutter/widgets.dart';

/// Layar lebar (tablet / landscape besar): nav jadi rail vertikal di kiri.
const double kWideBreakpoint = 1024;
const double kRailWidth = 84;

bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Ruang kosong di bawah konten supaya tidak tertutup nav melayang (+ mini player bila ada).
/// Di layar lebar nav ada di kiri, jadi hanya mini player yang perlu ruang.
double contentBottomPad(BuildContext context, {bool withPlayer = false}) {
  final safe = MediaQuery.paddingOf(context).bottom;
  final player = withPlayer ? 76.0 : 0.0;
  if (isWideLayout(context)) return 24 + safe + player;
  return 66 + 10 + safe + 24 + player;
}
