import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/routes.dart';
import '../../learning/learning_providers.dart';
import 'discipline_screen.dart';

class DisciplinePage extends ConsumerWidget {
  const DisciplinePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(disciplineProvider(id)),
      onRetry: () => ref.invalidate(disciplineProvider(id)),
      data: (d) => DisciplineScreen(
        discipline: d,
        onBack: context.pop,
        onLesson: (lessonId) => context.push(Routes.lesson(lessonId)),
        onQuiz: (topicId) => context.push(Routes.quiz(topicId)),
      ),
    );
  }
}
