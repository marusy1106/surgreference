import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Крупное число точечным шрифтом 5×7 (XP, балл, серия, таймер). Скринридер читает [semanticLabel].
class DotNumber extends StatelessWidget {
  const DotNumber(
    this.value, {
    super.key,
    required this.semanticLabel,
    this.dotSize = 6,
    this.color,
    this.showUnlit = true,
  });

  /// Цифры и `/ : % + - .` и пробел; прочие символы рисуются пробелом.
  final String value;
  final String semanticLabel;
  final double dotSize;
  final Color? color;
  final bool showUnlit;

  /// Число уже крупное: при системном шрифте 200 % растёт не больше чем в 1.5 раза.
  static const maxTextScale = 1.5;

  @override
  Widget build(BuildContext context) {
    final scale = math.min(MediaQuery.textScalerOf(context).scale(dotSize) / dotSize, maxTextScale);
    final ink = color ?? DefaultTextStyle.of(context).style.color ?? SrColors.of(context).text;
    final painter = _DotPainter(value, dotSize * scale, ink, showUnlit);
    return Semantics(
      // Отдельный узел: VoiceOver/TalkBack читает число целиком, не склеивая с соседним текстом.
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      // В узкой плитке число ужимается, а не вылезает за край. Не LayoutBuilder: он ломает IntrinsicHeight.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: CustomPaint(size: painter.size, painter: painter),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.value, this.dot, this.color, this.showUnlit);

  final String value;
  final double dot;
  final Color color;
  final bool showUnlit;

  double get _pitch => dot * 1.35;

  Size get size {
    final columns = value.split('').fold<int>(0, (sum, ch) => sum + _glyph(ch).first.length + 1) - 1;
    return Size(math.max(columns, 0) * _pitch, 7 * _pitch);
  }

  static List<String> _glyph(String ch) => _glyphs[ch] ?? _glyphs[' ']!;

  @override
  void paint(Canvas canvas, Size size) {
    final lit = Paint()..color = color;
    final unlit = Paint()..color = color.withValues(alpha: color.a * 0.12);
    var x0 = 0;
    for (final ch in value.split('')) {
      final rows = _glyph(ch);
      for (var y = 0; y < rows.length; y++) {
        for (var x = 0; x < rows[y].length; x++) {
          final on = rows[y][x] == '1';
          if (!on && !showUnlit) continue;
          final center = Offset((x0 + x + 0.5) * _pitch, (y + 0.5) * _pitch);
          canvas.drawCircle(center, dot / 2, on ? lit : unlit);
        }
      }
      x0 += rows.first.length + 1;
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.value != value || old.dot != dot || old.color != color || old.showUnlit != showUnlit;
}

const _glyphs = <String, List<String>>{
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  '/': ['00001', '00010', '00010', '00100', '01000', '01000', '10000'],
  ':': ['0', '0', '1', '0', '1', '0', '0'],
  '.': ['0', '0', '0', '0', '0', '0', '1'],
  '%': ['11001', '11010', '00010', '00100', '01000', '01011', '10011'],
  '+': ['00000', '00100', '00100', '11111', '00100', '00100', '00000'],
  '-': ['000', '000', '000', '111', '000', '000', '000'],
  ' ': ['00', '00', '00', '00', '00', '00', '00'],
};
