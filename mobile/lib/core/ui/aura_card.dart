import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Карточка дисциплины как в референсах Activity и Veri: глубокая основа, мягкое радиальное
/// свечение, лёгкое зерно и цветной ореол снаружи. Текст внутри — белый (см. [AuraInk]).
class AuraCard extends StatelessWidget {
  const AuraCard({
    super.key,
    required this.aura,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(SrSpace.xl),
    this.minHeight = 0,
    this.glow = true,
  });

  final Aura aura;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SrRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: glow
            ? [BoxShadow(color: aura.start.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16))]
            : null,
      ),
      child: Material(
        color: aura.end,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.75),
              radius: 1.25,
              colors: [
                aura.start.withValues(alpha: AuraInk.glowStrength),
                aura.start.withValues(alpha: 0),
              ],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: CustomPaint(
              painter: _Grain(),
              child: Container(
                constraints: BoxConstraints(minHeight: minHeight),
                padding: padding,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: AuraInk.ink),
                  child: IconTheme.merge(
                    data: const IconThemeData(color: AuraInk.ink),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Зерно поверх свечения — как на «мягких» градиентах референсов. Узор детерминированный:
/// одинаковый от кадра к кадру и в эталонных скриншотах.
class _Grain extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final light = Paint()..color = const Color(0x0FFFFFFF);
    final dark = Paint()..color = const Color(0x14000000);
    final count = (size.width * size.height / 60).round();
    for (var i = 0; i < count; i++) {
      final offset = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      canvas.drawCircle(offset, 0.7, i.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(_Grain old) => false;
}
