import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../../learning/data/learning_models.dart';
import '../../learning/learning_providers.dart';
import 'case_step_screen.dart';

/// Пошаговый кейс. Качество выбора и обратную связь сообщает сервер только после выбора;
/// в конце — разбор «ваш путь и оптимальный».
class CaseFlowPage extends ConsumerStatefulWidget {
  const CaseFlowPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CaseFlowPage> createState() => _CaseFlowPageState();
}

class _CaseFlowPageState extends ConsumerState<CaseFlowPage> {
  CaseSession? _session;
  CaseStep? _step;
  CaseOutcome? _outcome;
  CaseReview? _review;
  int? _chosen;
  final _history = <(String, String)>[];
  Object? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _session = null;
      _review = null;
      _outcome = null;
      _chosen = null;
      _history.clear();
    });
    try {
      final session = await ref.read(learningRepositoryProvider).startCase(widget.id);
      if (mounted) {
        setState(() {
          _session = session;
          _step = session.step;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _choose(int index) async {
    if (_busy || _outcome != null) return;
    setState(() {
      _busy = true;
      _chosen = index;
    });
    try {
      final outcome = await ref
          .read(learningRepositoryProvider)
          .chooseInCase(_session!.attemptId, _step!.choices[index].id);
      if (mounted) setState(() => _outcome = outcome);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _chosen = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    final outcome = _outcome!;
    final step = _step!;
    if (!outcome.finished) {
      setState(() {
        _history.add((step.title, step.summary));
        _step = outcome.nextStep;
        _outcome = null;
        _chosen = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final review = await ref.read(learningRepositoryProvider).caseReview(_session!.attemptId);
      invalidateStats(ref);
      if (mounted) setState(() => _review = review);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Кейс не загрузился',
              message: error is ApiException ? error.userMessage : 'Попробуйте ещё раз.',
              actionLabel: 'Повторить',
              onAction: _start,
            ),
          ),
        ),
      );
    }
    final review = _review;
    if (review != null) return _summary(review);
    final session = _session;
    final step = _step;
    if (session == null || step == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final outcome = _outcome;
    return CaseStepScreen(
      view: CaseStepView(
        title: session.summary.title,
        aura: session.summary.aura,
        steps: [...session.stepTitles, 'Итог'],
        current: step.number - 1,
        history: _history,
        situation: step.situation,
        prompt: step.prompt,
        // До выбора качество вариантов неизвестно; после — сервер назвал лучший.
        choices: [for (final c in step.choices) (c.text, outcome != null && c.id == outcome.optimalChoiceId)],
        chosen: outcome == null ? null : _chosen,
        feedback: outcome?.feedback,
        chosenGood: outcome?.isGood,
      ),
      onChoose: _choose,
      onNext: _busy ? null : _next,
      nextLabel: outcome?.finished == true ? 'К итогам' : 'Следующий шаг',
      onClose: context.pop,
    );
  }

  Widget _summary(CaseReview r) {
    final colors = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final right = r.steps.where((s) => s.chosenGood).length;
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
              aura: r.summary.aura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.summary.title, style: theme.labelLarge!.copyWith(color: AuraInk.inkMuted)),
                  const SizedBox(height: SrSpace.m),
                  DotNumber(
                    '$right/${r.steps.length}',
                    dotSize: 8,
                    semanticLabel: 'Верных решений $right из ${r.steps.length}',
                  ),
                  const SizedBox(height: SrSpace.s),
                  Text(
                    'верных решений · ${(r.score * 100).round()} % баллов · +${r.xpGained} XP',
                    style: theme.labelLarge!.copyWith(color: AuraInk.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            const SectionHeader('Ваш путь'),
            const SizedBox(height: SrSpace.s),
            for (final (i, step) in r.steps.indexed) ...[
              Tile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: theme.labelMedium!.copyWith(color: colors.textMuted)),
                    const SizedBox(height: SrSpace.s),
                    AnswerOption(
                      letter: '${i + 1}',
                      text: step.chosen,
                      state: step.chosenGood ? AnswerState.correct : AnswerState.incorrect,
                    ),
                    if (!step.chosenGood) ...[
                      const SizedBox(height: SrSpace.s),
                      AnswerOption(letter: '${i + 1}', text: step.optimal, state: AnswerState.missedCorrect),
                    ],
                    const SizedBox(height: SrSpace.s),
                    Text(step.feedback, style: theme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: SrSpace.s),
            ],
            if (r.debrief.isNotEmpty) ...[
              const SizedBox(height: SrSpace.l),
              const SectionHeader('Разбор'),
              const SizedBox(height: SrSpace.s),
              Text(r.debrief, style: theme.bodyLarge),
            ],
            const SizedBox(height: SrSpace.xl),
            PillButton(label: 'Пройти заново', onPressed: _start),
            const SizedBox(height: SrSpace.l),
            const Disclaimer(text: 'Учебный кейс. Пациент вымышлен. Не является руководством к лечению.'),
          ],
        ),
      ),
    );
  }
}
