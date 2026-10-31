import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Карточка дисциплины. У каждой темы свой язык:
/// - тёмная — как Activity и Veri: глубокая основа, радиальное свечение, зерно, цветной ореол, белый текст;
/// - светлая — как Aetna: белая карточка с тонкой рамкой, едва заметный оттенок дисциплины сверху,
///   тёмный текст и круглая чёрная кнопка-стрелка ↗, если карточку можно открыть ([cornerArrow]).
/// Цвет текста внутри — [AuraInk.inkOf] / [AuraInk.mutedOf].
class AuraCard extends StatelessWidget {
  const AuraCard({
    super.key,
    required this.aura,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(SrSpace.xl),
    this.minHeight = 0,
    this.glow = true,
    this.cornerArrow = false,
  });

  final Aura aura;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final bool glow;

  /// Светлая тема: круглая кнопка ↗ в правом верхнем углу (карточкам с местом под неё). Декоративная:
  /// нажимается вся карточка.
  final bool cornerArrow;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) return _light(context);
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

  Widget _light(BuildContext context) {
    final c = SrColors.of(context);
    final radius = BorderRadius.circular(SrRadius.card);
    final ink = c.text;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              aura.start.withValues(alpha: AuraInk.lightTint),
              aura.start.withValues(alpha: 0),
            ],
            stops: const [0, 0.7],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(minHeight: minHeight),
                padding: padding,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: ink),
                  child: IconTheme.merge(
                    data: IconThemeData(color: ink),
                    child: child,
                  ),
                ),
              ),
              if (cornerArrow)
                PositionedDirectional(
                  top: SrSpace.m,
                  end: SrSpace.m,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: Icon(Icons.north_east_rounded, size: 18, color: c.onAccent),
                    ),
                  ),
                ),
            ],
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
