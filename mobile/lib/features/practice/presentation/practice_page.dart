import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/routes.dart';
import '../../../core/ui/ui.dart';
import '../../learning/learning_providers.dart';

/// Вкладка «Практика»: повтор последнего теста, тесты по темам из каталога и клинические кейсы.
class PracticePage extends ConsumerWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final lastQuiz = ref.watch(overviewProvider).value?.lastQuiz;
    return AsyncView(
      value: ref.watch(casesProvider),
      onRetry: () => ref.invalidate(casesProvider),
      data: (cases) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(SrSpace.xl),
            children: [
              Text('Практика', style: theme.headlineMedium),
              const SizedBox(height: SrSpace.xl),
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
              if (cases.isEmpty) Text('Кейсы появятся после проверки рецензентом.', style: theme.bodyMedium),
              for (final c in cases) ...[
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
  const _ModeTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
