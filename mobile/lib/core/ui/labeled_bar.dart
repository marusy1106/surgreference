import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Горизонтальная полоса с подписью и процентом: освоение по дисциплинам.
class LabeledBar extends StatelessWidget {
  const LabeledBar({super.key, required this.label, required this.value, this.color});

  final String label;

  /// 0…1.
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final percent = '${(value * 100).round()} %';
    return Semantics(
      label: '$label: освоено $percent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.labelLarge)),
              Text(percent, style: theme.labelMedium!.copyWith(color: c.textMuted)),
            ],
          ),
          const SizedBox(height: SrSpace.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(SrRadius.pill),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 10,
              color: color ?? c.marker,
              backgroundColor: c.surface2,
            ),
          ),
        ],
      ),
    );
  }
}
