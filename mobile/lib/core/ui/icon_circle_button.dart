import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Круглая кнопка с иконкой; [semanticLabel] обязателен — иконка без подписи непонятна скринридеру.
class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.filled = false,
    this.size = 48,
  }) : assert(size >= kMinTapTarget);

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: filled ? c.accent : c.surface2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: size * 0.46, color: filled ? c.onAccent : c.text),
            ),
          ),
        ),
      ),
    );
  }
}
