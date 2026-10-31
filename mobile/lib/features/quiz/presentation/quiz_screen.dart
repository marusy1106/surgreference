import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

class QuizQuestionView {
  const QuizQuestionView({
    required this.index,
    required this.total,
    required this.topic,
    required this.aura,
    required this.text,
    required this.options,
    required this.timeLeft,
    required this.timeLimit,
    this.multiple = false,
    this.selected = const {},
  });

  /// С нуля.
  final int index;
  final int total;
  final String topic;
  final Aura aura;
  final String text;
  final List<String> options;
  final Duration timeLeft;
  final Duration timeLimit;
  final bool multiple;
  final Set<int> selected;
}

const optionLetters = ['А', 'Б', 'В', 'Г', 'Д', 'Е'];

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key, required this.question, this.onSelect, this.onAnswer, this.onClose});

  final QuizQuestionView question;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onAnswer;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final q = question;
    final left = q.timeLeft.inSeconds;
    final time = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SrSpace.l, SrSpace.s, SrSpace.xl, 0),
              child: Row(
                children: [
                  IconCircleButton(icon: Icons.close_rounded, semanticLabel: 'Прервать тест', onPressed: onClose),
                  const SizedBox(width: SrSpace.l),
                  Expanded(
                    child: StepIndicator(
                      count: q.total,
                      current: q.index,
                      semanticLabel: 'Вопрос ${q.index + 1} из ${q.total}',
                    ),
                  ),
                  const SizedBox(width: SrSpace.l),
                  Text('${q.index + 1}/${q.total}', style: theme.labelLarge),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(SrSpace.xl),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(q.topic, style: theme.labelLarge!.copyWith(color: c.textMuted)),
                      ),
                      DotNumber(time, dotSize: 3.5, semanticLabel: 'Осталось $time'),
                    ],
                  ),
                  const SizedBox(height: SrSpace.s),
                  RulerScale(
                    value: q.timeLeft.inSeconds / q.timeLimit.inSeconds,
                    ticks: 51,
                    semanticLabel: 'Осталось времени: $time',
                  ),
                  const SizedBox(height: SrSpace.xl),
                  AuraCard(
                    aura: q.aura,
                    minHeight: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.multiple ? 'Выберите все верные ответы' : 'Выберите один ответ',
                          style: theme.labelMedium!.copyWith(color: AuraInk.mutedOf(context)),
                        ),
                        const SizedBox(height: SrSpace.m),
                        Text(q.text, style: theme.titleLarge!.copyWith(color: AuraInk.inkOf(context))),
                      ],
                    ),
                  ),
                  const SizedBox(height: SrSpace.xl),
                  for (final (i, option) in q.options.indexed) ...[
                    AnswerOption(
                      letter: optionLetters[i],
                      text: option,
                      multiple: q.multiple,
                      state: q.selected.contains(i) ? AnswerState.selected : AnswerState.idle,
                      onTap: onSelect == null ? null : () => onSelect!(i),
                    ),
                    const SizedBox(height: SrSpace.s),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(SrSpace.xl, SrSpace.m, SrSpace.xl, SrSpace.l),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: PillButton(label: 'Ответить', onPressed: q.selected.isEmpty ? null : onAnswer),
            ),
          ],
        ),
      ),
    );
  }
}
