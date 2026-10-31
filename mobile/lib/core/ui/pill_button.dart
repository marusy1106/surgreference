import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

enum PillButtonVariant { primary, secondary }

/// Кнопка-пилюля со стрелкой в круге, как «Let's start» и «Start tracking» в референсах.
/// Тёмная тема: полупрозрачная пилюля с белым кругом; светлая: чёрная пилюля с белым кругом.
/// Вторичная — контурная, со стрелкой в контурном круге.
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = variant == PillButtonVariant.primary;
    final (Color fill, Color ink, Color border) = switch ((primary, dark)) {
      (true, true) => (c.text.withValues(alpha: 0.12), c.text, c.text.withValues(alpha: 0.22)),
      (true, false) => (c.accent, c.onAccent, c.accent),
      (false, _) => (Colors.transparent, c.text, c.text.withValues(alpha: 0.35)),
    };
    final enabled = onPressed != null;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const SizedBox(width: SrSpace.xl - SrSpace.s),
        Flexible(
          fit: expand ? FlexFit.tight : FlexFit.loose,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: ink, fontSize: 16)),
        ),
        if (showArrow) ...[
          const SizedBox(width: SrSpace.m),
          Container(
            width: 40,
            height: 40,
            decoration: primary
                ? BoxDecoration(color: ink, shape: BoxShape.circle)
                : BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: border),
                  ),
            child: Icon(Icons.arrow_forward_rounded, size: 20, color: primary ? (dark ? c.onAccent : c.accent) : ink),
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
          color: fill,
          shape: StadiumBorder(side: BorderSide(color: border)),
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
