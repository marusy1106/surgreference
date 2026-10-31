import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Индикатор шагов теста или кейса: пройденные, текущий (акцент), предстоящие.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.count, required this.current, this.semanticLabel})
    : assert(count > 0 && current >= 0 && current < count);

  final int count;

  /// С нуля.
  final int current;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Semantics(
      label: semanticLabel ?? 'Шаг ${current + 1} из $count',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: SrSpace.xs),
            Expanded(
              flex: i == current ? 3 : 1,
              child: AnimatedContainer(
                duration: SrMotion.normal,
                height: 6,
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: i == current
                      ? c.accent
                      : i < current
                      ? c.text
                      : c.textMuted.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
