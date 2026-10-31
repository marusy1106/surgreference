import 'package:flutter/material.dart';

const kFontFamily = 'Manrope';

/// Manrope вариативный: вес задаётся и через fontWeight, и через ось wght — иначе движок
/// рисует вариативный шрифт весом по умолчанию.
TextStyle srTextStyle(double size, FontWeight weight, {double? height, double letterSpacing = 0}) {
  return TextStyle(
    fontFamily: kFontFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Шкала 34 / 28 / 22 / 17 / 15 / 13 (docs/08-design.md, 8.2). Вес — как в референсах: заголовки средние,
/// не жирные; плотность даёт размер и слегка сжатый трекинг.
TextTheme srTextTheme(Color text, Color muted) {
  return TextTheme(
    headlineLarge: srTextStyle(34, FontWeight.w500, height: 1.15, letterSpacing: -1),
    headlineMedium: srTextStyle(28, FontWeight.w500, height: 1.2, letterSpacing: -0.7),
    titleLarge: srTextStyle(22, FontWeight.w500, height: 1.25, letterSpacing: -0.4),
    titleMedium: srTextStyle(17, FontWeight.w500, height: 1.35, letterSpacing: -0.1),
    bodyLarge: srTextStyle(17, FontWeight.w400, height: 1.55),
    bodyMedium: srTextStyle(15, FontWeight.w400, height: 1.45),
    bodySmall: srTextStyle(13, FontWeight.w400, height: 1.4).copyWith(color: muted),
    labelLarge: srTextStyle(15, FontWeight.w500, height: 1.3),
    labelMedium: srTextStyle(13, FontWeight.w500, height: 1.3),
    labelSmall: srTextStyle(12, FontWeight.w400, height: 1.3, letterSpacing: 0.2),
  ).apply(bodyColor: text, displayColor: text);
}
