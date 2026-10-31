import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

enum PillButtonVariant { primary, secondary }

/// Кнопка-пилюля с круглой стрелкой справа: «Начать →», «Продолжить →», «Ответить».
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.showArrow = true,
    this.expand = true,
  });

  final String label;

  /// null — кнопка неактивна.
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final bool showArrow;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final primary = variant == PillButtonVariant.primary;
    final bg = primary ? c.accent : c.surface2;
    final fg = primary ? c.onAccent : c.text;
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const SizedBox(width: SrSpace.xl - SrSpace.s),
        Flexible(
          fit: expand ? FlexFit.tight : FlexFit.loose,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: fg, fontSize: 16)),
        ),
        if (showArrow) ...[
          const SizedBox(width: SrSpace.m),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            child: Icon(Icons.arrow_forward_rounded, size: 20, color: bg),
          ),
        ] else
          const SizedBox(width: SrSpace.xl - SrSpace.s),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: SrMotion.fast,
        child: Material(
          color: bg,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(padding: const EdgeInsets.all(SrSpace.s), child: content),
            ),
          ),
        ),
      ),
    );
  }
}
