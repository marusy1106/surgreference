import 'package:flutter/material.dart';

import '../../../core/text/plural.dart';
import '../../../core/ui/ui.dart';
import '../../learning/data/learning_models.dart';

/// Дисциплина: темы, в каждой — уроки и тест темы.
class DisciplineScreen extends StatelessWidget {
  const DisciplineScreen({
    super.key,
    required this.discipline,
    required this.onBack,
    required this.onLesson,
    required this.onQuiz,
  });

  final DisciplineDetail discipline;
  final VoidCallback onBack;
  final ValueChanged<String> onLesson;
  final ValueChanged<String> onQuiz;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final d = discipline;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconCircleButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Назад', onPressed: onBack),
            ),
            const SizedBox(height: SrSpace.l),
            AuraCard(
              aura: d.aura,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${d.topics.length} ${plural(d.topics.length, 'тема', 'темы', 'тем')}',
                    style: theme.labelLarge!.copyWith(color: AuraInk.mutedOf(context)),
                  ),
                  const SizedBox(height: SrSpace.s),
                  Semantics(
                    header: true,
                    child: Text(d.title, style: theme.headlineMedium!.copyWith(color: AuraInk.inkOf(context))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            if (d.topics.isEmpty)
              const EmptyState(
                icon: Icons.edit_note_rounded,
                title: 'Материалы готовятся',
                message: 'Темы появятся после проверки медицинским рецензентом.',
              ),
            for (final topic in d.topics) ...[
              Tile(
                padding: const EdgeInsets.all(SrSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(header: true, child: Text(topic.title, style: theme.titleMedium)),
                    if (topic.lessons.isEmpty && topic.quizId == null) ...[
                      const SizedBox(height: SrSpace.xs),
                      Text('Материалы готовятся', style: theme.bodySmall),
                    ],
                    for (final lesson in topic.lessons)
                      _Row(
                        icon: lesson.completed ? Icons.check_circle_rounded : Icons.article_outlined,
                        iconColor: lesson.completed ? c.success : c.textMuted,
                        title: lesson.title,
                        subtitle: lesson.completed ? 'Пройден · ${lesson.minutes} мин' : 'Урок · ${lesson.minutes} мин',
                        onTap: () => onLesson(lesson.id),
                      ),
                    if (topic.quizId case final quizId?)
                      _Row(
                        icon: Icons.quiz_outlined,
                        iconColor: c.accent,
                        title: 'Тест по теме',
                        subtitle:
                            '${topic.quizQuestions} ${plural(topic.quizQuestions, 'вопрос', 'вопроса', 'вопросов')} с разбором',
                        onTap: () => onQuiz(quizId),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: SrSpace.m),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SrRadius.tile),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SrSpace.s),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: SrSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.labelLarge),
                    Text(subtitle, style: theme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: SrColors.of(context).textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
