import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Плитка сетки на главной и в прогрессе. Ширину (1×1 или 2×1) задаёт раскладка.
class Tile extends StatelessWidget {
  const Tile({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(SrSpace.l)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(SrRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Подпись плитки: мелкий заголовок сверху.
class TileLabel extends StatelessWidget {
  const TileLabel(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(color: c.textMuted);
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: c.textMuted), const SizedBox(width: SrSpace.xs)],
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
