import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Token desain "Soft Pink Glass" (sumber: public/theme.css). Tema terang saja, TANPA glow.
class T {
  static const Color bg1 = Color(0xFFFFF6F9);
  static const Color bg2 = Color(0xFFFFE9F1);
  static const Color bg3 = Color(0xFFFBD9E7);

  static const Color ink = Color(0xFF3A2530);
  static const Color ink2 = Color(0xFF5F4655);
  static const Color ink3 = Color(0xFF7D6270);
  static const Color ink4 = Color(0xFFB89AA9);

  static const Color accent = Color(0xFFD4467A);
  static const Color accent2 = Color(0xFFB83264);
  static const Color danger = Color(0xFFC43C52);
  static const Color accentSoft = Color.fromRGBO(212, 70, 122, .10);
  static const Color accentTint = Color.fromRGBO(212, 70, 122, .22);

  static const Color glass = Color.fromRGBO(255, 255, 255, .55);
  static const Color glass2 = Color.fromRGBO(255, 255, 255, .74);
  static const Color glass3 = Color.fromRGBO(255, 255, 255, .36);
  static const Color glassEdge = Color.fromRGBO(255, 255, 255, .90);
  static const Color line = Color.fromRGBO(150, 80, 110, .14);
  static const Color scrim = Color.fromRGBO(70, 35, 55, .26);

  static const double rXl = 26;
  static const double rLg = 20;
  static const double rMd = 14;
  static const double rSm = 10;
  static const double rPill = 999;

  static const Curve ease = Cubic(.22, 1, .36, 1);
  static const Duration dur = Duration(milliseconds: 280);

  static const List<BoxShadow> shadow = [
    BoxShadow(color: Color.fromRGBO(110, 60, 85, .08), offset: Offset(0, 8), blurRadius: 24),
  ];
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color.fromRGBO(110, 60, 85, .06), offset: Offset(0, 2), blurRadius: 10),
  ];

  static ImageFilter blur([double sigma = 18]) => ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

  static const String fontFamily = 'PlusJakartaSans';
}
