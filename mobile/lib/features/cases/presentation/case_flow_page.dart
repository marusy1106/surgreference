import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../core/ui/ui.dart';
import '../../learning/data/learning_models.dart';
import '../../learning/learning_providers.dart';
import 'case_step_screen.dart';

/// Пошаговый кейс: решение на каждом шаге → обратная связь → итог «ваш путь и оптимальный».
class CaseFlowPage extends ConsumerStatefulWidget {
  const CaseFlowPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CaseFlowPage> createState() => _CaseFlowPageState();
}

class _CaseFlowPageState extends ConsumerState<CaseFlowPage> {
  var _step = 0;
  int? _chosen;
  final _path = <int>[];

  @override
  Widget build(BuildContext context) {
    return AsyncView(
      value: ref.watch(caseProvider(widget.id)),
      onRetry: () => ref.invalidate(caseProvider(widget.id)),
      data: (c) => _step >= c.steps.length ? _summary(c) : _stepScreen(c),
    );
  }

  Widget _stepScreen(ClinicalCase c) {
    final step = c.steps[_step];
    final chosen = _chosen;
    return CaseStepScreen(
      view: CaseStepView(
        title: c.summary.title,
        aura: c.summary.aura,
        steps: [for (final s in c.steps) s.title, 'Итог'],
        current: _step,
        history: [for (final s in c.steps.take(_step)) (s.title, s.summary)],
        situation: step.situation,
        prompt: step.prompt,
        choices: [for (final choice in step.choices) (choice.text, choice.correct)],
        chosen: chosen,
        feedback: chosen == null ? null : step.choices[chosen].feedback,
      ),
      onChoose: (i) => setState(() => _chosen = i),
      onNext: () => setState(() {
        _path.add(_chosen!);
        _chosen = null;
        _step++;
      }),
      onClose: context.pop,
    );
  }

  Widget _summary(ClinicalCase c) {
    final colors = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final right = [for (final (i, s) in c.steps.indexed) s.choices[_path[i]].correct].where((ok) => ok).length;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Row(
              children: [
                Expanded(child: Text('Итог кейса', style: theme.headlineMedium)),
                IconCircleButton(icon: Icons.close_rounded, semanticLabel: 'Закрыть', onPressed: context.pop),
              ],
            ),
            const SizedBox(height: SrSpace.l),
            AuraCard(
              aura: c.summary.aura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.summary.title, style: theme.labelLarge!.copyWith(color: AuraInk.inkMuted)),
                  const SizedBox(height: SrSpace.m),
                  DotNumber(
                    '$right/${c.steps.length}',
                    dotSize: 8,
                    semanticLabel: 'Верных решений $right из ${c.steps.length}',
                  ),
                  const SizedBox(height: SrSpace.s),
                  Text('верных решений', style: theme.labelLarge!.copyWith(color: AuraInk.ink)),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            const SectionHeader('Ваш путь'),
            const SizedBox(height: SrSpace.s),
            for (final (i, step) in c.steps.indexed) ...[
              Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: theme.labelMedium!.copyWith(color: colors.textMuted)),
                    const SizedBox(height: SrSpace.s),
                    AnswerOption(
                      letter: '${i + 1}',
                      text: step.choices[_path[i]].text,
                      state: step.choices[_path[i]].correct ? AnswerState.correct : AnswerState.incorrect,
                    ),
                    if (!step.choices[_path[i]].correct) ...[
                      const SizedBox(height: SrSpace.s),
                      AnswerOption(
                        letter: '${i + 1}',
                        text: step.choices.firstWhere((ch) => ch.correct).text,
                        state: AnswerState.missedCorrect,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SrSpace.s),
            ],
            const SizedBox(height: SrSpace.l),
            const SectionHeader('Разбор'),
            const SizedBox(height: SrSpace.s),
            Text(c.takeaway, style: theme.bodyLarge),
            const SizedBox(height: SrSpace.xl),
            PillButton(
              label: 'Пройти заново',
              onPressed: () => setState(() {
                _step = 0;
                _chosen = null;
                _path.clear();
              }),
            ),
            const SizedBox(height: SrSpace.l),
            const Disclaimer(),
          ],
        ),
      ),
    );
  }
}
