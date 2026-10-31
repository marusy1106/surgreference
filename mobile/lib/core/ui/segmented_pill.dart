import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Переключатель-пилюля: «Неделя / Месяц / Год», «Студенты / Вузы».
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({super.key, required this.segments, required this.selected, required this.onChanged});

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final style = Theme.of(context).textTheme.labelLarge!;
    return Container(
      padding: const EdgeInsets.all(SrSpace.xs),
      decoration: ShapeDecoration(color: c.surface2, shape: const StadiumBorder()),
      child: Row(
        children: [
          for (final MapEntry(key: value, value: label) in segments.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: Material(
                  color: value == selected ? c.text : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: kMinTapTarget),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: SrSpace.s, vertical: SrSpace.s),
                          // На крупном шрифте подпись ужимается, а не рвётся посреди слова.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              style: style.copyWith(color: value == selected ? c.bg : c.textMuted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
