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

  /// null-поля — карточки нет (новый пользователь, всё пройдено, контента ещё нет).
  /// progress — доля прочитанного; null — урок ещё не начат.
  final ({String id, String discipline, String title, double? progress, Aura aura})? continueLesson;
  final ({String topicId, String topic, int score, int total, Aura aura})? lastQuiz;
  final ({String id, String title, String discipline, Aura aura})? caseOfDay;
  final int streakDays;
  final int streakGoal;
  final int weekXp;
  final int weekXpDelta;
  final double mastery;

  /// null — ещё нет ответов, по которым её определить.
  final String? weakTopic;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.view,
    this.onContinue,
    this.onLastQuiz,
    this.onCase,
    this.onProgress,
    this.onCatalog,
  });

  final HomeView view;
  final VoidCallback? onContinue;
  final VoidCallback? onLastQuiz;
  final VoidCallback? onCase;
  final VoidCallback? onProgress;
  final VoidCallback? onCatalog;

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
            if (v.continueLesson == null && v.lastQuiz == null && v.caseOfDay == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SrSpace.xl),
                child: Tile(
                  onTap: onCatalog,
                  child: Row(
                    children: [
                      Expanded(child: Text('Выберите тему в каталоге, чтобы начать', style: theme.titleMedium)),
                      Icon(Icons.chevron_right_rounded, color: c.textMuted),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 150 + 70 * scale,
                child: PageView(
                  controller: PageController(viewportFraction: 0.86),
                  padEnds: false,
                  // Иначе свечение карточек обрезается прямоугольником.
                  clipBehavior: Clip.none,
                  children: [
                    if (v.continueLesson case final lesson?)
                      _CarouselCard(
                        aura: lesson.aura,
                        label: 'Продолжить урок · ${lesson.discipline}',
                        onTap: onContinue,
                        title: lesson.title,
                        footer: switch (lesson.progress) {
                          final progress? => RulerScale(
                            value: progress,
                            ticks: 31,
                            color: AuraInk.ink,
                            semanticLabel: 'Прочитано ${(progress * 100).round()} %',
                            endLabel: '${(progress * 100).round()} %',
                          ),
                          null => const Row(
                            children: [
                              Expanded(child: Text('Открыть урок')),
                              Icon(Icons.arrow_outward_rounded),
                            ],
                          ),
                        },
                      ),
                    if (v.lastQuiz case final quiz?)
                      _CarouselCard(
                        aura: quiz.aura,
                        label: 'Последний тест · ${quiz.topic}',
                        onTap: onLastQuiz,
                        footer: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: DotNumber(
                                  '${quiz.score}/${quiz.total}',
                                  dotSize: 7,
                                  semanticLabel: 'Результат ${quiz.score} из ${quiz.total}',
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_outward_rounded),
                          ],
                        ),
                      ),
                    if (v.caseOfDay case final clinicalCase?)
                      _CarouselCard(
                        aura: clinicalCase.aura,
                        label: 'Кейс дня · ${clinicalCase.discipline}',
                        onTap: onCase,
                        title: clinicalCase.title,
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
                                  v.weekXpDelta >= 0 ? '+${v.weekXpDelta} к прошлой' : '−${-v.weekXpDelta} к прошлой',
                                  style: theme.labelMedium!.copyWith(
                                    color: v.weekXpDelta > 0 ? c.success : c.textMuted,
                                  ),
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
                              TileLabel(v.weakTopic == null ? 'Освоение' : 'Слабая тема'),
                              const SizedBox(height: SrSpace.xs),
                              Text(v.weakTopic ?? 'Пройдите тест — покажем, что повторить', style: theme.titleMedium),
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
