import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:surgreference/app/shell.dart';
import 'package:surgreference/design_preview/demo_data.dart';
import 'package:surgreference/features/auth/presentation/verify_code_screen.dart';
import 'package:surgreference/features/cases/presentation/case_step_screen.dart';
import 'package:surgreference/features/catalog/presentation/catalog_screen.dart';
import 'package:surgreference/features/home/presentation/home_screen.dart';
import 'package:surgreference/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:surgreference/features/lesson/presentation/lesson_screen.dart';
import 'package:surgreference/features/onboarding/presentation/onboarding_screen.dart';
import 'package:surgreference/features/profile/presentation/profile_screen.dart';
import 'package:surgreference/features/progress/presentation/progress_screen.dart';
import 'package:surgreference/features/quiz/presentation/quiz_result_screen.dart';
import 'package:surgreference/features/quiz/presentation/quiz_screen.dart';
import 'package:surgreference/features/references/presentation/guideline_screens.dart';
import 'package:surgreference/features/references/presentation/icd_screens.dart';

Widget _tab(AppTab tab, Widget child) => AppShell(tab: tab, onTab: (_) {}, child: child);

/// Ключевые экраны MVP на демо-данных, в порядке пользовательского пути.
final keyScreens = <String, Widget Function()>{
  '01_onboarding': () => OnboardingScreen(onStart: () {}, onLogin: () {}),
  '02_verify_code': () => VerifyCodeScreen(
    maskedEmail: 'a•••@example.org',
    controller: TextEditingController(text: '4821'),
    autofocus: false,
    resendIn: const Duration(seconds: 42),
    errorText: 'Неверный код. Осталось 4 попытки.',
    onBack: () {},
    onSubmit: (_) {},
  ),
  '03_home': () => _tab(AppTab.home, const HomeScreen(view: Demo.home)),
  '04_catalog': () => _tab(AppTab.catalog, const CatalogScreen(disciplines: Demo.disciplines)),
  '05_lesson': () => const LessonScreen(lesson: Demo.lesson),
  '06_quiz': () => QuizScreen(question: Demo.quizQuestion, onSelect: (_) {}, onAnswer: () {}, onClose: () {}),
  '07_quiz_result': () => const QuizResultScreen(result: Demo.quizResult),
  '08_case_step': () => const CaseStepScreen(view: Demo.caseStep),
  '09_progress': () => ProgressScreen(view: Demo.progress, onBack: () {}),
  '10_leaderboard': () => _tab(AppTab.leaderboard, const LeaderboardScreen(rows: Demo.leaderboard, me: Demo.me)),
  '11_profile': () => _tab(AppTab.profile, const ProfileScreen(view: Demo.profile)),
  '12_icd_search': () => const IcdSearchScreen(query: 'к35', results: AsyncValue.data(Demo.icdSearch)),
  '13_icd_code': () => IcdCodeScreen(detail: Demo.icdCode),
  '14_guidelines': () => GuidelinesScreen(results: AsyncValue.data(Demo.guidelines)),
  '15_guideline': () => GuidelineScreen(detail: Demo.guideline),
};
