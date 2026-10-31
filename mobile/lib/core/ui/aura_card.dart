import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Карточка с градиентом дисциплины и мягким цветным свечением. Текст внутри — тёмный (см. [AuraInk]).
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
            ? [BoxShadow(color: aura.start.withValues(alpha: 0.32), blurRadius: 36, offset: const Offset(0, 14))]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: aura.gradient),
          child: InkWell(
            onTap: onTap,
            child: Container(
              color: Colors.white.withValues(alpha: AuraInk.veilOpacity),
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
    );
  }
}
