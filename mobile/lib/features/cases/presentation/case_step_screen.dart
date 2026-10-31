import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../quiz/presentation/quiz_screen.dart' show optionLetters;

class CaseStepView {
  const CaseStepView({
    required this.title,
    required this.aura,
    required this.steps,
    required this.current,
    required this.history,
    required this.situation,
    required this.prompt,
    required this.choices,
    this.chosen,
    this.feedback,
  });

  final String title;
  final Aura aura;

  /// Названия шагов: анамнез → осмотр → обследование → решение.
  final List<String> steps;

  /// С нуля.
  final int current;

  /// Краткое содержание пройденных шагов.
  final List<(String, String)> history;
  final String situation;
  final String prompt;
  final List<(String, bool)> choices;
  final int? chosen;
  final String? feedback;
}

class CaseStepScreen extends StatelessWidget {
  const CaseStepScreen({super.key, required this.view, this.onChoose, this.onNext, this.onClose});

  final CaseStepView view;
  final ValueChanged<int>? onChoose;
  final VoidCallback? onNext;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final v = view;
    final chosen = v.chosen;
    final chosenCorrect = chosen != null && v.choices[chosen].$2;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Row(
              children: [
                IconCircleButton(icon: Icons.close_rounded, semanticLabel: 'Выйти из кейса', onPressed: onClose),
                const SizedBox(width: SrSpace.l),
                Expanded(
                  child: StepIndicator(
                    count: v.steps.length,
                    current: v.current,
                    semanticLabel: 'Шаг ${v.current + 1} из ${v.steps.length}: ${v.steps[v.current]}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: SrSpace.xl),
            Text('Синтетический кейс', style: theme.labelMedium!.copyWith(color: c.textMuted)),
            const SizedBox(height: SrSpace.xs),
            Text(v.title, style: theme.headlineMedium),
            const SizedBox(height: SrSpace.l),
            for (final (step, summary) in v.history) ...[
              Tile(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20, color: c.textMuted),
                    const SizedBox(width: SrSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step, style: theme.labelMedium!.copyWith(color: c.textMuted)),
                          const SizedBox(height: 2),
                          Text(summary, style: theme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SrSpace.s),
            ],
            const SizedBox(height: SrSpace.s),
            AuraCard(
              aura: v.aura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.steps[v.current], style: theme.labelLarge!.copyWith(color: AuraInk.inkMuted)),
                  const SizedBox(height: SrSpace.s),
                  Text(v.situation, style: theme.bodyLarge!.copyWith(color: AuraInk.ink)),
                  const SizedBox(height: SrSpace.m),
                  Text(v.prompt, style: theme.titleMedium!.copyWith(color: AuraInk.ink)),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.l),
            for (final (i, (text, correct)) in v.choices.indexed) ...[
              AnswerOption(
                letter: optionLetters[i],
                text: text,
                state: chosen == null
                    ? AnswerState.idle
                    : i == chosen
                    ? (correct ? AnswerState.correct : AnswerState.incorrect)
                    : (correct ? AnswerState.missedCorrect : AnswerState.idle),
                onTap: chosen == null && onChoose != null ? () => onChoose!(i) : null,
              ),
              const SizedBox(height: SrSpace.s),
            ],
            if (v.feedback != null) ...[
              const SizedBox(height: SrSpace.s),
              Container(
                padding: const EdgeInsets.all(SrSpace.l),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(SrRadius.tile),
                  border: Border.all(color: chosenCorrect ? c.success : c.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chosenCorrect ? 'Верное решение' : 'Есть решение лучше',
                      style: theme.labelLarge!.copyWith(color: chosenCorrect ? c.success : c.error),
                    ),
                    const SizedBox(height: SrSpace.xs),
                    Text(v.feedback!, style: theme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: SrSpace.l),
              PillButton(label: 'Следующий шаг', onPressed: onNext),
            ],
            const SizedBox(height: SrSpace.l),
            const Disclaimer(),
          ],
        ),
      ),
    );
  }
}
