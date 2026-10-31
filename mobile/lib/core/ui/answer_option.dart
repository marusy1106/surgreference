import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Состояния варианта ответа. До завершения теста — [idle] и [selected], на разборе — остальные.
enum AnswerState { idle, selected, correct, incorrect, missedCorrect }

/// Вариант ответа во всю ширину. Состояние передаётся цветом, иконкой и подписью — не только цветом.
class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.letter,
    required this.text,
    this.state = AnswerState.idle,
    this.multiple = false,
    this.onTap,
  });

  final String letter;
  final String text;
  final AnswerState state;

  /// Множественный выбор: квадратная метка вместо круглой.
  final bool multiple;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final (Color? tone, IconData? icon, String? caption) = switch (state) {
      AnswerState.idle => (null, null, null),
      AnswerState.selected => (c.accent, null, null),
      AnswerState.correct => (c.success, Icons.check_rounded, 'Верно'),
      AnswerState.incorrect => (c.error, Icons.close_rounded, 'Ваш ответ — неверно'),
      AnswerState.missedCorrect => (c.success, Icons.check_rounded, 'Правильный ответ'),
    };
    final filled = state == AnswerState.selected || state == AnswerState.correct || state == AnswerState.incorrect;
    final badgeShape = multiple
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
        : const CircleBorder();
    return Semantics(
      button: onTap != null,
      selected: state == AnswerState.selected,
      label: [letter, text, ?caption].join('. '),
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: SrMotion.fast,
        decoration: ShapeDecoration(
          color: tone == null ? c.surface : Color.alphaBlend(tone.withValues(alpha: 0.12), c.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SrRadius.tile + 4),
            side: BorderSide(color: tone ?? c.line, width: tone == null ? 1 : 2),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(SrRadius.tile + 4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SrSpace.m, vertical: SrSpace.m),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(color: filled ? tone : c.surface2, shape: badgeShape),
                      child: icon != null && filled
                          ? Icon(icon, size: 20, color: c.bg)
                          : Text(letter, style: theme.labelLarge!.copyWith(color: filled ? c.onAccent : c.text)),
                    ),
                    const SizedBox(width: SrSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(text, style: theme.bodyMedium),
                          if (caption != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(caption, style: theme.labelMedium!.copyWith(color: tone)),
                            ),
                        ],
                      ),
                    ),
                    if (state == AnswerState.missedCorrect) ...[
                      const SizedBox(width: SrSpace.s),
                      Icon(icon, color: tone),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
