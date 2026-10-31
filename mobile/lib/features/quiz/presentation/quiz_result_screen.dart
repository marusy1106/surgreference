import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import 'quiz_screen.dart';

class ResultItemView {
  const ResultItemView({required this.question, required this.correct, this.options = const [], this.explanation});

  final String question;
  final bool correct;

  /// Варианты с состояниями разбора; пусто — вопрос свёрнут.
  final List<(String, AnswerState)> options;
  final String? explanation;
}

class QuizResultView {
  const QuizResultView({
    required this.topic,
    required this.aura,
    required this.score,
    required this.total,
    required this.xpGained,
    required this.items,
  });

  final String topic;
  final Aura aura;
  final int score;
  final int total;
  final int xpGained;
  final List<ResultItemView> items;
}

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    super.key,
    required this.result,
    this.onClose,
    this.onMistakes,
    this.onRate,
    this.onItemTap,
    this.rated,
    this.onLesson,
  });

  /// Повторить урок темы — ссылка из разбора.
  final VoidCallback? onLesson;

  final QuizResultView result;

  /// Раскрыть или свернуть разбор вопроса по индексу.
  final ValueChanged<int>? onItemTap;

  /// Оценка уже поставлена: true — полезен, false — нет.
  final bool? rated;
  final VoidCallback? onClose;
  final VoidCallback? onMistakes;
  final ValueChanged<bool>? onRate;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final r = result;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Row(
              children: [
                Expanded(child: Text('Результат', style: theme.headlineMedium)),
                IconCircleButton(icon: Icons.close_rounded, semanticLabel: 'Закрыть', onPressed: onClose),
              ],
            ),
            const SizedBox(height: SrSpace.l),
            AuraCard(
              aura: r.aura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.topic, style: theme.labelLarge!.copyWith(color: AuraInk.inkMuted)),
                  const SizedBox(height: SrSpace.l),
                  DotNumber('${r.score}/${r.total}', dotSize: 9, semanticLabel: 'Результат ${r.score} из ${r.total}'),
                  const SizedBox(height: SrSpace.l),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: SrSpace.m, vertical: SrSpace.xs + 2),
                    decoration: const ShapeDecoration(color: AuraInk.ink, shape: StadiumBorder()),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 18, color: SrColors.dark.accent),
                        const SizedBox(width: SrSpace.xs),
                        Text('+${r.xpGained} XP', style: theme.labelLarge!.copyWith(color: SrColors.dark.accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            const SectionHeader('Разбор'),
            const SizedBox(height: SrSpace.s),
            for (final (i, item) in r.items.indexed) ...[
              _ResultItem(number: i + 1, item: item, onTap: onItemTap == null ? null : () => onItemTap!(i)),
              const SizedBox(height: SrSpace.s),
            ],
            const SizedBox(height: SrSpace.l),
            Tile(
              child: rated != null
                  ? FormMessage('Спасибо, оценка учтена.', isError: false)
                  : Row(
                      children: [
                        Expanded(child: Text('Разбор был полезен?', style: theme.titleMedium)),
                        IconCircleButton(
                          icon: Icons.thumb_up_alt_outlined,
                          semanticLabel: 'Полезен',
                          onPressed: onRate == null ? null : () => onRate!(true),
                        ),
                        const SizedBox(width: SrSpace.s),
                        IconCircleButton(
                          icon: Icons.thumb_down_alt_outlined,
                          semanticLabel: 'Не полезен',
                          onPressed: onRate == null ? null : () => onRate!(false),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: SrSpace.xl),
            PillButton(label: 'Пройти ещё раз', onPressed: onMistakes),
            if (onLesson != null) ...[
              const SizedBox(height: SrSpace.s),
              PillButton(
                label: 'Повторить урок',
                variant: PillButtonVariant.secondary,
                showArrow: false,
                onPressed: onLesson,
              ),
            ],
            const SizedBox(height: SrSpace.s),
            PillButton(label: 'На главную', variant: PillButtonVariant.secondary, showArrow: false, onPressed: onClose),
            const SizedBox(height: SrSpace.s),
            Text(
              'Сообщить об ошибке в вопросе можно из разбора.',
              style: theme.bodySmall!.copyWith(color: c.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  const _ResultItem({required this.number, required this.item, this.onTap});

  final int number;
  final ResultItemView item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final tone = item.correct ? c.success : c.error;
    final expanded = item.options.isNotEmpty;
    return Tile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: item.correct ? 'Верно' : 'Неверно',
                excludeSemantics: true,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                  child: Icon(item.correct ? Icons.check_rounded : Icons.close_rounded, size: 18, color: c.bg),
                ),
              ),
              const SizedBox(width: SrSpace.m),
              Expanded(child: Text('$number. ${item.question}', style: theme.labelLarge)),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.textMuted),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: SrSpace.m),
            for (final (i, (text, state)) in item.options.indexed) ...[
              AnswerOption(letter: optionLetters[i], text: text, state: state),
              const SizedBox(height: SrSpace.s),
            ],
            if (item.explanation != null) ...[
              const SizedBox(height: SrSpace.xs),
              Text('Почему так', style: theme.labelLarge),
              const SizedBox(height: SrSpace.xs),
              Text(item.explanation!, style: theme.bodyMedium),
            ],
          ],
        ],
      ),
    );
  }
}
