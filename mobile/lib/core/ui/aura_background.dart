import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Размытая «сфера» с орбитами, как в финансовом референсе: вытянутый овал — тёплое ядро цвета
/// дисциплины и холодный синий край, тонкие белые орбиты. Медленно «дышит»; при системном
/// «Уменьшении движения» стоит на месте.
class AuraBackground extends StatefulWidget {
  const AuraBackground({super.key, required this.aura, this.alignment = const Alignment(0, -0.35), this.child});

  final Aura aura;
  final Alignment alignment;
  final Widget? child;

  @override
  State<AuraBackground> createState() => _AuraBackgroundState();
}

class _AuraBackgroundState extends State<AuraBackground> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: SrMotion.breath);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.aura;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final d = math.min(constraints.maxWidth, constraints.maxHeight) * 0.95;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_controller.value);
                  return Align(
                    alignment: widget.alignment,
                    child: SizedBox.square(
                      dimension: d * 1.6,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: d * 0.07, sigmaY: d * 0.07),
                            child: Transform.scale(
                              scale: 0.94 + 0.08 * t,
                              child: Container(
                                width: d * 0.62,
                                height: d * 0.9,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.elliptical(d * 0.31, d * 0.45)),
                                  gradient: RadialGradient(
                                    colors: [
                                      Color.lerp(aura.start, const Color(0xFFFFD2A8), 0.55)!,
                                      aura.start,
                                      _coolRim,
                                      _coolRim.withValues(alpha: 0),
                                    ],
                                    stops: const [0, 0.42, 0.82, 1],
                                    center: Alignment(0.1 - 0.2 * t, 0.15),
                                    radius: 0.62,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: Size.square(d * 1.6),
                            painter: _OrbitPainter(d, t, SrColors.of(context).text),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        ?widget.child,
      ],
    );
  }
}

const _coolRim = Color(0xFF3E5BE0);

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.d, this.t, this.ink);

  final double d;
  final double t;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ink.withValues(alpha: 0.32);
    for (final (i, k) in [0.62, 0.82, 1.02].indexed) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.35 + i * 0.22 + t * 0.06);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: d * k * 1.25, height: d * k * 0.55), paint);
      canvas.restore();
    }
    final dot = Paint()..color = ink.withValues(alpha: 0.8);
    final a = 0.8 + t * 0.4;
    canvas.drawCircle(center + Offset(math.cos(a) * d * 0.62 * 0.625, math.sin(a) * d * 0.15), 3, dot);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t || old.d != d || old.ink != ink;
}
