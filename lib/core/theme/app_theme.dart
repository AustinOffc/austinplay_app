import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: T.accent,
    brightness: Brightness.light,
  ).copyWith(primary: T.accent, onPrimary: Colors.white, error: T.danger, surface: T.bg1);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: T.fontFamily,
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: T.ink, displayColor: T.ink),
    dialogTheme: DialogThemeData(
      backgroundColor: T.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rLg)),
    ),
  );
}
