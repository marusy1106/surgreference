import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/ui/ui.dart';
import '../../learning/learning_providers.dart';

/// Вкладка «Практика»: тесты по темам и клинические кейсы.
class PracticePage extends ConsumerWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final isDemo = ref.watch(learningRepositoryProvider).isDemo;
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
              if (isDemo) ...[
                const SizedBox(height: SrSpace.m),
                const Align(alignment: Alignment.centerLeft, child: DemoBadge()),
              ],
              const SizedBox(height: SrSpace.xl),
              const SectionHeader('Тесты'),
              const SizedBox(height: SrSpace.s),
              _ModeTile(
                icon: Icons.quiz_outlined,
                title: 'Тест по теме',
                subtitle: 'Острый аппендицит · 5 вопросов с разбором',
                onTap: () => context.push(Routes.quiz('appendicitis')),
              ),
              const SizedBox(height: SrSpace.s),
              _ModeTile(
                icon: Icons.menu_book_outlined,
                title: 'Выбрать тему в каталоге',
                subtitle: 'Тест есть в конце каждой темы',
                onTap: () => context.go(Routes.catalog),
              ),
              const SizedBox(height: SrSpace.xl),
              const SectionHeader('Клинические кейсы'),
              const SizedBox(height: SrSpace.s),
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
