import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/routes.dart';
import '../../learning/learning_providers.dart';
import 'home_screen.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(homeProvider),
      onRetry: () => ref.invalidate(homeProvider),
      data: (view) => RefreshIndicator(
        onRefresh: () => ref.refresh(homeProvider.future),
        child: HomeScreen(
          view: view,
          onContinue: () => context.push(Routes.lesson(view.continueLesson.id)),
          onLastQuiz: () => context.push(Routes.quiz(view.lastQuiz.topicId)),
          onCase: () => context.push(Routes.clinicalCase(view.caseOfDay.id)),
          onProgress: () => context.push(Routes.progress),
        ),
      ),
    );
  }
}
