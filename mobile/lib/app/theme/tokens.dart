import 'package:flutter/material.dart';

/// Цвета темы (docs/08-design.md, 8.2). Контраст пар проверяет test/app/contrast_test.dart.
@immutable
class SrColors extends ThemeExtension<SrColors> {
  const SrColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.error,
    required this.warning,
    required this.marker,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color error;
  final Color warning;

  /// Маленький яркий маркер: бегунок шкалы, дуга прогресса, текущая точка. Не для заливок и текста.
  final Color marker;

  // Референсы (Activity, Veri, финансовое приложение): чёрный фон, белый «акцент» — выбранный чип,
  // кнопка, точка навигации; лайм — только маркер на шкалах.
  static const dark = SrColors(
    bg: Color(0xFF060607),
    surface: Color(0xFF131315),
    surface2: Color(0xFF1C1C1F),
    line: Color(0x1AFFFFFF),
    text: Color(0xFFF4F4F6),
    textMuted: Color(0xFF9C9CA5),
    accent: Color(0xFFF4F4F6),
    onAccent: Color(0xFF060607),
    success: Color(0xFF5BD69A),
    error: Color(0xFFFF6B6B),
    warning: Color(0xFFFFB547),
    marker: Color(0xFFD6F45B),
  );

  // Aetna: светло-серый фон, белые карточки с тонкой рамкой, чёрные выбранные чипы и круглые кнопки.
  static const light = SrColors(
    bg: Color(0xFFEDEDEB),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F4F2),
    line: Color(0x1F000000),
    text: Color(0xFF0E0E10),
    textMuted: Color(0xFF5F5F66),
    accent: Color(0xFF0E0E10),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF13703F),
    error: Color(0xFFB82C2C),
    warning: Color(0xFF985A00),
    marker: Color(0xFF4E6FD8),
  );

  static SrColors of(BuildContext context) => Theme.of(context).extension<SrColors>()!;

  @override
  SrColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? line,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? error,
    Color? warning,
    Color? marker,
  }) {
    return SrColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      line: line ?? this.line,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      marker: marker ?? this.marker,
    );
  }

  @override
  SrColors lerp(SrColors? other, double t) {
    if (other == null) return this;
    return SrColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      marker: Color.lerp(marker, other.marker, t)!,
    );
  }
}

/// Ауры дисциплин; имя значения — `palette_token` дисциплины в API.
/// [start] — свечение, [end] — глубокая основа карточки (как в референсах Activity и Veri).
enum Aura {
  surgery(Color(0xFFC8441B), Color(0xFF1F0905)),
  therapy(Color(0xFFC42A78), Color(0xFF1D0614)),
  cardiology(Color(0xFFC42346), Color(0xFF1C0510)),
  neurology(Color(0xFF5A43E0), Color(0xFF0D0A2A)),
  pediatrics(Color(0xFF16806A), Color(0xFF03140F)),
  pharmacology(Color(0xFF2F5BE0), Color(0xFF060F2A));

  const Aura(this.start, this.end);

  final Color start;
  final Color end;

  /// Неизвестный токен (новая дисциплина в старой версии приложения) не роняет экран.
  static Aura fromToken(String? token) => values.firstWhere((aura) => aura.name == token, orElse: () => surgery);

  /// Самое яркое место карточки: свечение поверх основы. По нему проверяется контраст текста.
  Color get peak => Color.lerp(end, start, AuraInk.glowStrength)!;
}

/// Текст на карточке дисциплины. Тёмная тема: белый на свечении (подобрано так, что даже в самой
/// яркой точке контраст ≥ 4.5). Светлая: обычный тёмный текст на белой карточке с лёгким оттенком.
abstract final class AuraInk {
  static const ink = Color(0xFFFFFFFF);
  static const inkMuted = Color(0xDBFFFFFF);
  static const glowStrength = 0.85;

  /// Оттенок дисциплины на белой карточке светлой темы — едва заметный, текст остаётся на белом.
  static const lightTint = 0.10;

  static bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color inkOf(BuildContext context) => _dark(context) ? ink : SrColors.of(context).text;

  static Color mutedOf(BuildContext context) => _dark(context) ? inkMuted : SrColors.of(context).textMuted;
}

abstract final class SrSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class SrRadius {
  static const double card = 32;
  static const double tile = 26;
  static const double pill = 999;
}

abstract final class SrMotion {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const breath = Duration(seconds: 10);
}

/// Минимальная тач-цель (docs/08-design.md, 8.4).
const double kMinTapTarget = 44;
