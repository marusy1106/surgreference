import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

class HomeView {
  const HomeView({
    required this.nickname,
    required this.continueLesson,
    required this.lastQuiz,
    required this.caseOfDay,
    required this.streakDays,
    required this.streakGoal,
    required this.weekXp,
    required this.weekXpDelta,
    required this.mastery,
    required this.weakTopic,
  });

  final String nickname;
  final ({String discipline, String title, double progress, Aura aura}) continueLesson;
  final ({String topic, int score, int total, Aura aura}) lastQuiz;
  final ({String title, String discipline, Aura aura}) caseOfDay;
  final int streakDays;
  final int streakGoal;
  final int weekXp;
  final int weekXpDelta;
  final double mastery;
  final String weakTopic;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.view, this.onContinue, this.onLastQuiz, this.onCase, this.onProgress});

  final HomeView view;
  final VoidCallback? onContinue;
  final VoidCallback? onLastQuiz;
  final VoidCallback? onCase;
  final VoidCallback? onProgress;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final v = view;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: SrSpace.l),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SrSpace.xl),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Привет,', style: theme.bodyMedium!.copyWith(color: c.textMuted)),
                        Text(v.nickname, style: theme.headlineMedium),
                      ],
                    ),
                  ),
                  InitialsAvatar(v.nickname, size: 48),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            SizedBox(
              height: 150 + 70 * scale,
              child: PageView(
                controller: PageController(viewportFraction: 0.86),
                padEnds: false,
                // Иначе свечение карточек обрезается прямоугольником.
                clipBehavior: Clip.none,
                children: [
                  _CarouselCard(
                    aura: v.continueLesson.aura,
                    label: 'Продолжить урок · ${v.continueLesson.discipline}',
                    onTap: onContinue,
                    title: v.continueLesson.title,
                    footer: RulerScale(
                      value: v.continueLesson.progress,
                      ticks: 31,
                      color: AuraInk.ink,
                      semanticLabel: 'Прочитано ${(v.continueLesson.progress * 100).round()} %',
                      endLabel: '${(v.continueLesson.progress * 100).round()} %',
                    ),
                  ),
                  _CarouselCard(
                    aura: v.lastQuiz.aura,
                    label: 'Последний тест · ${v.lastQuiz.topic}',
                    onTap: onLastQuiz,
                    footer: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: DotNumber(
                              '${v.lastQuiz.score}/${v.lastQuiz.total}',
                              dotSize: 7,
                              semanticLabel: 'Результат ${v.lastQuiz.score} из ${v.lastQuiz.total}',
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_outward_rounded),
                      ],
                    ),
                  ),
                  _CarouselCard(
                    aura: v.caseOfDay.aura,
                    label: 'Кейс дня · ${v.caseOfDay.discipline}',
                    onTap: onCase,
                    title: v.caseOfDay.title,
                    footer: const Text('Синтетический учебный кейс'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SrSpace.xl),
              child: Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Tile(
                            onTap: onProgress,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TileLabel('Серия дней', icon: Icons.local_fire_department_outlined),
                                const SizedBox(height: SrSpace.m),
                                DotNumber(
                                  '${v.streakDays}',
                                  dotSize: 6,
                                  color: c.accent,
                                  semanticLabel: 'Серия ${v.streakDays} дней',
                                ),
                                const SizedBox(height: SrSpace.m),
                                RulerScale(
                                  value: v.streakDays / v.streakGoal,
                                  ticks: 21,
                                  semanticLabel: 'Цель ${v.streakGoal} дней',
                                  endLabel: 'цель ${v.streakGoal}',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: SrSpace.m),
                        Expanded(
                          child: Tile(
                            onTap: onProgress,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TileLabel('XP за неделю', icon: Icons.bolt_rounded),
                                const SizedBox(height: SrSpace.m),
                                DotNumber('${v.weekXp}', dotSize: 6, semanticLabel: '${v.weekXp} XP за неделю'),
                                const Spacer(),
                                const SizedBox(height: SrSpace.m),
                                Text(
                                  '+${v.weekXpDelta} к прошлой',
                                  style: theme.labelMedium!.copyWith(color: c.success),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SrSpace.m),
                  Tile(
                    onTap: onProgress,
                    child: Row(
                      children: [
                        ProgressRing(
                          value: v.mastery,
                          size: 56,
                          semanticLabel: 'Освоение ${(v.mastery * 100).round()} %',
                          child: Text('${(v.mastery * 100).round()}%', style: theme.labelMedium),
                        ),
                        const SizedBox(width: SrSpace.l),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TileLabel('Слабая тема'),
                              const SizedBox(height: SrSpace.xs),
                              Text(v.weakTopic, style: theme.titleMedium),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.textMuted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.aura, required this.label, required this.footer, this.title, this.onTap});

  final Aura aura;
  final String label;
  final String? title;
  final Widget footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: SrSpace.xl, bottom: SrSpace.xl),
      child: AuraCard(
        aura: aura,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.labelMedium!.copyWith(color: AuraInk.inkMuted),
            ),
            const SizedBox(height: SrSpace.s),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  overflow: TextOverflow.fade,
                  style: theme.titleLarge!.copyWith(color: AuraInk.ink),
                ),
              )
            else
              const Spacer(),
            footer,
          ],
        ),
      ),
    );
  }
}
