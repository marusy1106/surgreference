import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/routes.dart';
import '../../../core/text/plural.dart';
import '../../../core/ui/ui.dart';
import '../../learning/learning_providers.dart';

const _mistakesMin = 5;

final _practiceTabProvider = FutureProvider.autoDispose(
  (ref) async => (disciplines: await ref.watch(practiceProvider.future), cases: await ref.watch(casesProvider.future)),
);

/// Вкладка «Практика»: тренировка и работа над ошибками по дисциплинам, повтор последнего теста,
/// тесты по темам из каталога и клинические кейсы.
class PracticePage extends ConsumerWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final lastQuiz = ref.watch(overviewProvider).value?.lastQuiz;
    return AsyncView(
      value: ref.watch(_practiceTabProvider),
      onRetry: () => ref
        ..invalidate(practiceProvider)
        ..invalidate(casesProvider),
      data: (tab) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(SrSpace.xl),
            children: [
              Text('Практика', style: theme.headlineMedium),
              const SizedBox(height: SrSpace.xl),
              const SectionHeader('Тренировка'),
              const SizedBox(height: SrSpace.s),
              if (tab.disciplines.isEmpty)
                Text('Вопросы для тренировки появятся после проверки рецензентом.', style: theme.bodyMedium),
              for (final d in tab.disciplines) ...[
                _ModeTile(
                  icon: Icons.fitness_center_rounded,
                  title: d.title,
                  subtitle: d.questions < 10
                      ? '${d.questions} ${plural(d.questions, 'вопрос', 'вопроса', 'вопросов')} в случайном порядке'
                      : '10 случайных вопросов, чаще — из слабых тем',
                  onTap: () => context.push(Routes.training(d.slug)),
                ),
                const SizedBox(height: SrSpace.s),
              ],
              const SizedBox(height: SrSpace.l),
              const SectionHeader('Работа над ошибками'),
              const SizedBox(height: SrSpace.s),
              if (tab.disciplines.every((d) => d.mistakes == 0))
                Text(
                  'Здесь соберутся вопросы, на которые вы ответили неверно. '
                  'Работа над ошибками откроется после $_mistakesMin ошибок в дисциплине.',
                  style: theme.bodyMedium,
                ),
              for (final d in tab.disciplines.where((d) => d.mistakes > 0)) ...[
                _ModeTile(
                  icon: Icons.healing_rounded,
                  title: d.title,
                  subtitle: d.mistakesAvailable
                      ? '${d.mistakes} ${plural(d.mistakes, 'ошибка', 'ошибки', 'ошибок')} — верный ответ уберёт вопрос из списка'
                      : 'Откроется после $_mistakesMin ошибок, сейчас ${d.mistakes}',
                  onTap: d.mistakesAvailable ? () => context.push(Routes.mistakes(d.slug)) : null,
                ),
                const SizedBox(height: SrSpace.s),
              ],
              const SizedBox(height: SrSpace.l),
              const SectionHeader('Тесты'),
              const SizedBox(height: SrSpace.s),
              if (lastQuiz != null) ...[
                _ModeTile(
                  icon: Icons.replay_rounded,
                  title: 'Повторить: ${lastQuiz.topic}',
                  subtitle: 'Прошлый результат ${lastQuiz.correct} из ${lastQuiz.total}',
                  onTap: () => context.push(Routes.quiz(lastQuiz.quizId)),
                ),
                const SizedBox(height: SrSpace.s),
              ],
              _ModeTile(
                icon: Icons.menu_book_outlined,
                title: 'Тест по теме',
                subtitle: 'Выберите тему в каталоге — тест в конце каждой темы',
                onTap: () => context.go(Routes.catalog),
              ),
              const SizedBox(height: SrSpace.xl),
              const SectionHeader('Клинические кейсы'),
              const SizedBox(height: SrSpace.s),
              if (tab.cases.isEmpty) Text('Кейсы появятся после проверки рецензентом.', style: theme.bodyMedium),
              for (final c in tab.cases) ...[
                AuraCard(
                  aura: c.aura,
                  onTap: () => context.push(Routes.clinicalCase(c.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.discipline} · синтетический кейс',
                        style: theme.labelMedium!.copyWith(color: AuraInk.inkMuted),
                      ),
                      const SizedBox(height: SrSpace.s),
                      Text(c.title, style: theme.titleLarge!.copyWith(color: AuraInk.ink)),
                      if (c.summary.isNotEmpty) ...[
                        const SizedBox(height: SrSpace.xs),
                        Text(c.summary, style: theme.bodyMedium!.copyWith(color: AuraInk.ink)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: SrSpace.m),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;

  /// null — режим пока закрыт: вместо стрелки замок.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Tile(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: kMinTapTarget,
            height: kMinTapTarget,
            decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
            child: Icon(icon, color: c.text),
          ),
          const SizedBox(width: SrSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.titleMedium),
                Text(subtitle, style: theme.bodySmall),
              ],
            ),
          ),
          Icon(onTap == null ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
