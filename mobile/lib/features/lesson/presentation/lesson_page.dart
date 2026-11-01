import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../learning/learning_providers.dart';
import 'lesson_screen.dart';

class LessonPage extends ConsumerWidget {
  const LessonPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void message(String text) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    return AsyncView(
      value: ref.watch(lessonProvider(id)),
      onRetry: () => ref.invalidate(lessonProvider(id)),
      data: (lesson) => LessonScreen(
        lesson: lesson,
        onBack: context.pop,
        onComplete: () async {
          await ref.read(learningRepositoryProvider).completeLesson(id);
          invalidateStats(ref);
          if (context.mounted) {
            message('Урок пройден');
            context.pop();
          }
        },
        onOpenIcd: (code) => context.push(Routes.icdCode(code)),
        onOpenGuideline: (guidelineId) => context.push(Routes.guideline(guidelineId)),
        onReport: () => message('Форма «Сообщить об ошибке» появится вместе с обратной связью на сервере.'),
      ),
    );
  }
}
