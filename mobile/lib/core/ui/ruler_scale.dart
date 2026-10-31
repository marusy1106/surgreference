import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Шкала-линейка с маркером: серия дней, таймер теста, освоение.
class RulerScale extends StatelessWidget {
  const RulerScale({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.ticks = 41,
    this.startLabel,
    this.endLabel,
    this.color,
  }) : assert(ticks > 1);

  /// 0…1.
  final double value;
  final String semanticLabel;
  final int ticks;
  final String? startLabel;
  final String? endLabel;

  /// Цвет делений; по умолчанию — цвет текста. Маркер всегда акцентный.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final ink = color ?? DefaultTextStyle.of(context).style.color ?? c.text;
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(color: ink.withValues(alpha: 0.7));
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 28, child: CustomPaint(painter: _RulerPainter(value.clamp(0, 1), ticks, ink, c.accent))),
          if (startLabel != null || endLabel != null) ...[
            const SizedBox(height: SrSpace.xs),
            Row(
              children: [
                if (startLabel != null) Text(startLabel!, style: labelStyle),
                const Spacer(),
                if (endLabel != null) Text(endLabel!, style: labelStyle),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.value, this.ticks, this.ink, this.marker);

  final double value;
  final int ticks;
  final Color ink;
  final Color marker;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / (ticks - 1);
    final markerX = value * size.width;
    final paint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < ticks; i++) {
      final x = i * step;
      final major = i % 5 == 0;
      final h = major ? size.height * 0.62 : size.height * 0.38;
      paint.color = x <= markerX ? ink : ink.withValues(alpha: ink.a * 0.28);
      canvas.drawLine(Offset(x, size.height - h), Offset(x, size.height), paint);
    }
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(markerX.clamp(2, size.width - 2), size.height / 2), width: 4, height: size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, Paint()..color = marker);
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.value != value || old.ticks != ticks || old.ink != ink || old.marker != marker;
}
