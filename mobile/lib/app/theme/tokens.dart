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

  static const dark = SrColors(
    bg: Color(0xFF0B0B0D),
    surface: Color(0xFF151518),
    surface2: Color(0xFF1E1E22),
    line: Color(0x14FFFFFF),
    text: Color(0xFFF4F4F6),
    textMuted: Color(0xFF9C9CA5),
    accent: Color(0xFFD6F45B),
    onAccent: Color(0xFF0B0B0D),
    success: Color(0xFF5BD69A),
    error: Color(0xFFFF6B6B),
    warning: Color(0xFFFFB547),
  );

  // Акцент и статусы темнее, чем в первой версии токенов: те не давали 4.5:1 на светлых поверхностях.
  static const light = SrColors(
    bg: Color(0xFFF3F3F1),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFECECEA),
    line: Color(0x14000000),
    text: Color(0xFF0E0E10),
    textMuted: Color(0xFF5F5F66),
    accent: Color(0xFF335CCF),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF13703F),
    error: Color(0xFFB82C2C),
    warning: Color(0xFF985A00),
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
    );
  }
}

/// Ауры дисциплин; имя значения — `palette_token` дисциплины в API.
enum Aura {
  surgery(Color(0xFFFF5A36), Color(0xFFFFB38A)),
  therapy(Color(0xFFE0357F), Color(0xFFF2B3D3)),
  cardiology(Color(0xFFE63946), Color(0xFF9B5DE5)),
  neurology(Color(0xFF4D4DE8), Color(0xFFA99BF5)),
  pediatrics(Color(0xFF6CC4A1), Color(0xFFCDE6D8)),
  pharmacology(Color(0xFF2F5BEA), Color(0xFF8FB3FF));

  const Aura(this.start, this.end);

  final Color start;
  final Color end;

  /// Неизвестный токен (новая дисциплина в старой версии приложения) не роняет экран.
  static Aura fromToken(String? token) => values.firstWhere((aura) => aura.name == token, orElse: () => surgery);

  LinearGradient get gradient =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [start, end]);
}

/// Текст на ауре — тёмный поверх светлой вуали: белый текст на светлых концах градиентов
/// давал контраст 1.3–4.1, тёмный на вуали 30 % — не ниже 5.9.
abstract final class AuraInk {
  static const ink = Color(0xFF0B0B0D);
  static const inkMuted = Color(0xD90B0B0D);
  static const veilOpacity = 0.3;
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
  static const double card = 28;
  static const double tile = 20;
  static const double pill = 999;
}

abstract final class SrMotion {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const breath = Duration(seconds: 10);
}

/// Минимальная тач-цель (docs/08-design.md, 8.4).
const double kMinTapTarget = 44;
