import 'package:flutter/material.dart';

import '../app/shell.dart';
import '../core/ui/ui.dart';
import '../features/auth/presentation/verify_code_screen.dart';
import '../features/cases/presentation/case_step_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/lesson/presentation/lesson_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/quiz/presentation/quiz_result_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import 'demo_data.dart';

/// Кликабельный прототип этапа 4 на демо-данных. На этапе 5 заменяется настоящим роутером.
class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SurgReference',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: Builder(
        builder: (context) => OnboardingScreen(
          onStart: () => _push(context, (c) => _Code(onDone: () => _openShell(c))),
          onLogin: () => _openShell(context),
        ),
      ),
    );
  }

  static void _openShell(BuildContext context) =>
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const _Shell()), (_) => false);
}

void _push(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push(MaterialPageRoute(builder: builder));

class _Code extends StatelessWidget {
  const _Code({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => VerifyCodeScreen(
    maskedEmail: 'a•••@example.org',
    code: '482193',
    resendIn: const Duration(seconds: 42),
    onBack: () => Navigator.of(context).pop(),
    onSubmit: onDone,
  );
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  AppTab _tab = AppTab.home;
  CatalogFilter _filter = CatalogFilter.all;
  LeaderboardMode _mode = LeaderboardMode.students;
  LeaderboardScope _scope = LeaderboardScope.myUniversity;

  void _lesson() => _push(
    context,
    (c) =>
        LessonScreen(lesson: Demo.lesson, onBack: () => Navigator.of(c).pop(), onComplete: () => Navigator.of(c).pop()),
  );

  void _result() => _push(
    context,
    (c) => QuizResultScreen(
      result: Demo.quizResult,
      onClose: () => Navigator.of(c).pop(),
      onMistakes: () => Navigator.of(c).pop(),
    ),
  );

  void _case() => _push(
    context,
    (c) =>
        CaseStepScreen(view: Demo.caseStep, onClose: () => Navigator.of(c).pop(), onNext: () => Navigator.of(c).pop()),
  );

  void _progress() => _push(context, (c) => ProgressScreen(view: Demo.progress, onBack: () => Navigator.of(c).pop()));

  @override
  Widget build(BuildContext context) {
    return AppShell(
      tab: _tab,
      onTab: (t) => setState(() => _tab = t),
      child: switch (_tab) {
        AppTab.home => HomeScreen(
          view: Demo.home,
          onContinue: _lesson,
          onLastQuiz: _result,
          onCase: _case,
          onProgress: _progress,
        ),
        AppTab.catalog => CatalogScreen(
          disciplines: Demo.disciplines,
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
          onOpen: (_) => _lesson(),
        ),
        AppTab.practice => _PracticeDemo(onFinish: _result),
        AppTab.leaderboard => LeaderboardScreen(
          rows: Demo.leaderboard,
          me: Demo.me,
          mode: _mode,
          scope: _scope,
          onMode: (m) => setState(() => _mode = m),
          onScope: (s) => setState(() => _scope = s),
        ),
        AppTab.profile => ProfileScreen(view: Demo.profile, onProgress: _progress),
      },
    );
  }
}

class _PracticeDemo extends StatefulWidget {
  const _PracticeDemo({required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<_PracticeDemo> createState() => _PracticeDemoState();
}

class _PracticeDemoState extends State<_PracticeDemo> {
  Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    const q = Demo.quizQuestion;
    return QuizScreen(
      question: QuizQuestionView(
        index: q.index,
        total: q.total,
        topic: q.topic,
        aura: q.aura,
        text: q.text,
        options: q.options,
        timeLeft: q.timeLeft,
        timeLimit: q.timeLimit,
        selected: _selected,
      ),
      onSelect: (i) => setState(() => _selected = {i}),
      onAnswer: widget.onFinish,
    );
  }
}
