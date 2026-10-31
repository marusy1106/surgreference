import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

enum ProgressPeriod { week, month, year }

class ProgressView {
  const ProgressView({
    required this.period,
    required this.level,
    required this.xpInLevel,
    required this.xpForLevel,
    required this.activity,
    required this.activityLabels,
    required this.activitySummary,
    required this.mastery,
    required this.lessons,
    required this.quizzes,
    required this.cases,
  });

  final ProgressPeriod period;
  final int level;
  final int xpInLevel;
  final int xpForLevel;
  final List<double> activity;
  final List<String> activityLabels;
  final String activitySummary;
  final List<(String, double, Aura)> mastery;
  final int lessons;
  final int quizzes;
  final int cases;
}

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.view, this.onPeriod, this.onBack});

  final ProgressView view;
  final ValueChanged<ProgressPeriod>? onPeriod;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final v = view;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Row(
              children: [
                if (onBack != null) ...[
                  IconCircleButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Назад', onPressed: onBack),
                  const SizedBox(width: SrSpace.m),
                ],
                Expanded(child: Text('Прогресс', style: theme.headlineMedium)),
              ],
            ),
            const SizedBox(height: SrSpace.l),
            SegmentedPill<ProgressPeriod>(
              segments: const {
                ProgressPeriod.week: 'Неделя',
                ProgressPeriod.month: 'Месяц',
                ProgressPeriod.year: 'Год',
              },
              selected: v.period,
              onChanged: (p) => onPeriod?.call(p),
            ),
            const SizedBox(height: SrSpace.l),
            Tile(
              padding: const EdgeInsets.all(SrSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TileLabel('Уровень знаний'),
                            const SizedBox(height: SrSpace.s),
                            DotNumber('${v.level}', dotSize: 8, color: c.accent, semanticLabel: 'Уровень ${v.level}'),
                          ],
                        ),
                      ),
                      Text(
                        '${v.xpInLevel} / ${v.xpForLevel} XP',
                        style: theme.labelLarge!.copyWith(color: c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: SrSpace.l),
                  RulerScale(
                    value: v.xpInLevel / v.xpForLevel,
                    semanticLabel: 'До уровня ${v.level + 1} осталось ${v.xpForLevel - v.xpInLevel} XP',
                    startLabel: 'ур. ${v.level}',
                    endLabel: 'ур. ${v.level + 1}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.m),
            Tile(
              padding: const EdgeInsets.all(SrSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TileLabel('Активность, XP'),
                  const SizedBox(height: SrSpace.l),
                  ActivityChart(values: v.activity, labels: v.activityLabels, semanticSummary: v.activitySummary),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.m),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (label, n)) in [
                    ('Уроков', v.lessons),
                    ('Тестов', v.quizzes),
                    ('Кейсов', v.cases),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: SrSpace.m),
                    Expanded(
                      child: Tile(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$n', style: theme.headlineMedium),
                            Text(label, style: theme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            const SectionHeader('Освоение по дисциплинам'),
            const SizedBox(height: SrSpace.m),
            for (final (title, value, aura) in v.mastery) ...[
              LabeledBar(label: title, value: value, color: aura.start),
              const SizedBox(height: SrSpace.l),
            ],
          ],
        ),
      ),
    );
  }
}
