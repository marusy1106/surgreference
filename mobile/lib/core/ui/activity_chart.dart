import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Линейный график активности с маркером последней точки. Скринридер читает [semanticSummary].
class ActivityChart extends StatelessWidget {
  const ActivityChart({
    super.key,
    required this.values,
    required this.labels,
    required this.semanticSummary,
    this.height = 160,
  });

  /// Не меньше двух точек.
  final List<double> values;

  /// Подписи оси X (несколько, распределяются равномерно).
  final List<String> labels;
  final String semanticSummary;
  final double height;

  @override
  Widget build(BuildContext context) {
    assert(values.length >= 2, 'ActivityChart needs at least two points');
    final c = SrColors.of(context);
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(color: c.textMuted);
    return Semantics(
      label: semanticSummary,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(painter: _ChartPainter(values, c)),
          ),
          const SizedBox(height: SrSpace.s),
          // Подписи оси вспомогательные (смысл графика — в semanticSummary), поэтому растут не больше 1.5×.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: Row(
              children: [
                for (final (i, label) in labels.indexed)
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: labelStyle,
                      textAlign: i == 0
                          ? TextAlign.start
                          : i == labels.length - 1
                          ? TextAlign.end
                          : TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.c);

  final List<double> values;
  final SrColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = maxV <= 0 ? 1.0 : maxV * 1.15;
    const pad = 8.0;
    Offset at(int i) =>
        Offset(i * size.width / (values.length - 1), pad + (size.height - 2 * pad) * (1 - values[i] / top));

    final grid = Paint()
      ..color = c.line
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = pad + (size.height - 2 * pad) * k / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = at(i - 1);
      final p1 = at(i);
      final mx = (p0.dx + p1.dx) / 2;
      line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.marker.withValues(alpha: 0.28), c.marker.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = c.marker,
    );
    final last = at(values.length - 1);
    canvas.drawLine(
      Offset(last.dx, pad),
      Offset(last.dx, size.height),
      grid..color = c.textMuted.withValues(alpha: 0.4),
    );
    canvas.drawCircle(last, 7, Paint()..color = c.bg);
    canvas.drawCircle(last, 5, Paint()..color = c.marker);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.values != values || old.c != c;
}
