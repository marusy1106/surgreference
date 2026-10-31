import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Чип-фильтр: «Все / Начатые / Освоенные».
class ChipFilter extends StatelessWidget {
  const ChipFilter({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.accent : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : c.textMuted.withValues(alpha: 0.4))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelected(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SrSpace.l, vertical: SrSpace.s + 2),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(color: selected ? c.onAccent : c.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
