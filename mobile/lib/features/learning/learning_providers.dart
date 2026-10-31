import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../catalog/presentation/catalog_screen.dart';
import '../education/data/education_models.dart';
import '../education/education_providers.dart';
import '../home/presentation/home_screen.dart';
import '../leaderboard/presentation/leaderboard_screen.dart';
import '../lesson/presentation/lesson_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../progress/presentation/progress_screen.dart';
import 'data/learning_models.dart';

final overviewProvider = FutureProvider.autoDispose<ProgressOverview>(
  (ref) => ref.watch(learningRepositoryProvider).overview(),
);

final casesProvider = FutureProvider.autoDispose<List<CaseSummary>>(
  (ref) => ref.watch(learningRepositoryProvider).cases(),
);

/// Цель серии на главной: ближайший рубеж достижений (3, 7, 30 дней).
int streakGoal(int days) => days < 3 ? 3 : (days < 7 ? 7 : 30);

final practiceProvider = FutureProvider.autoDispose<List<PracticeDiscipline>>(
  (ref) => ref.watch(learningRepositoryProvider).practice(),
);

final homeProvider = FutureProvider.autoDispose<HomeView>((ref) async {
  final overview = await ref.watch(overviewProvider.future);
  final cases = await ref.watch(casesProvider.future);
  final dismissed = ref.watch(educationPromptDismissedProvider);
  // Без профиля главная работает: ошибка загрузки профиля только прячет карточку.
  final education = dismissed
      ? null
      : await ref.watch(educationProvider.future).then<EducationProfile?>((e) => e, onError: (Object _) => null);
  final lesson = overview.continueLesson;
  final quiz = overview.lastQuiz;
  // «Кейс дня» меняется ежедневно: детерминированный выбор по номеру дня.
  final today = DateTime.now().difference(DateTime(2026)).inDays;
  final clinicalCase = cases.isEmpty ? null : cases[today % cases.length];
  return HomeView(
    nickname: ref.watch(nicknameProvider),
    continueLesson: lesson == null
        ? null
        : (id: lesson.id, discipline: lesson.discipline, title: lesson.title, progress: null, aura: lesson.aura),
    lastQuiz: quiz == null
        ? null
        : (topicId: quiz.quizId, topic: quiz.topic, score: quiz.correct, total: quiz.total, aura: quiz.aura),
    caseOfDay: clinicalCase == null
        ? null
        : (
            id: clinicalCase.id,
            title: clinicalCase.title,
            discipline: clinicalCase.discipline,
            aura: clinicalCase.aura,
          ),
    streakDays: overview.currentStreak,
    streakGoal: streakGoal(overview.currentStreak),
    weekXp: overview.weekXp,
    weekXpDelta: overview.weekXp - overview.previousWeekXp,
    mastery: overview.averageMastery,
    weakTopic: overview.weakTopic?.title,
    askEducation: education != null && education.status == null,
  );
});

final disciplinesProvider = FutureProvider.autoDispose<List<DisciplineCardView>>((ref) async {
  final list = await ref.watch(learningRepositoryProvider).disciplines();
  return [
    for (final d in list)
      DisciplineCardView(id: d.slug, title: d.title, aura: d.aura, topics: d.topics, mastery: d.mastery),
  ];
});

final disciplineProvider = FutureProvider.autoDispose.family<DisciplineDetail, String>(
  (ref, slug) => ref.watch(learningRepositoryProvider).discipline(slug),
);

final lessonProvider = FutureProvider.autoDispose.family<LessonView, String>(
  (ref, id) => ref.watch(learningRepositoryProvider).lesson(id),
);

const _periods = {ProgressPeriod.week: 'week', ProgressPeriod.month: 'month', ProgressPeriod.year: 'year'};

final progressProvider = FutureProvider.autoDispose.family<ProgressView, ProgressPeriod>((ref, period) async {
  final overview = await ref.watch(overviewProvider.future);
  final points = await ref.watch(learningRepositoryProvider).activity(_periods[period]!);
  final total = points.fold<int>(0, (sum, p) => sum + p.xp);
  final best = points.fold<int>(0, (m, p) => p.xp > m ? p.xp : m);
  // На оси — 4–5 подписей, иначе 30 дат не помещаются.
  final step = (points.length / 4).ceil().clamp(1, points.length);
  return ProgressView(
    period: period,
    level: overview.level,
    xpInLevel: overview.totalXp - overview.levelXp,
    xpForLevel: overview.nextLevelXp - overview.levelXp,
    activity: [for (final p in points) p.xp.toDouble()],
    activityLabels: [
      for (var i = 0; i < points.length; i += step) points[i].label,
      if ((points.length - 1) % step != 0) points.last.label,
    ],
    activitySummary: total == 0
        ? 'За период пока нет активности.'
        : 'За период $total XP, лучший результат — $best XP.',
    mastery: [
      for (final d in overview.disciplines)
        if (d.topics > 0) (d.title, d.mastery, d.aura),
    ],
    lessons: overview.lessonsCompleted,
    quizzes: overview.quizzesFinished,
    cases: overview.casesFinished,
  );
});

final leaderboardProvider = FutureProvider.autoDispose.family<Board, (LeaderboardMode, LeaderboardScope, String)>(
  (ref, args) => ref.watch(learningRepositoryProvider).leaderboard(args.$1, args.$2, args.$3),
);

/// Иконки достижений приходят именами Material Icons.
const achievementIcons = <String, IconData>{
  'menu_book': Icons.menu_book_rounded,
  'flag': Icons.flag_rounded,
  'medical_services': Icons.medical_services_rounded,
  'verified': Icons.verified_rounded,
  'auto_stories': Icons.auto_stories_rounded,
  'emoji_events': Icons.emoji_events_rounded,
  'local_fire_department': Icons.local_fire_department_rounded,
  'whatshot': Icons.whatshot_rounded,
  'healing': Icons.healing_rounded,
};

final profileProvider = FutureProvider.autoDispose<ProfileView>((ref) async {
  final overview = await ref.watch(overviewProvider.future);
  final achievements = await ref.watch(learningRepositoryProvider).achievements();
  final education = await ref.watch(educationProvider.future);
  final earnedFirst = [...achievements]..sort((a, b) => (b.earned ? 1 : 0) - (a.earned ? 1 : 0));
  return ProfileView(
    nickname: ref.watch(nicknameProvider),
    level: overview.level,
    xpTotal: overview.totalXp,
    status: education.statusLine,
    university: education.universityLine,
    achievements: [
      for (final a in earnedFirst)
        AchievementView(title: a.title, icon: achievementIcons[a.icon] ?? Icons.star_rounded, unlocked: a.earned),
    ],
  );
});

/// После урока, теста или кейса статистика на вкладках устарела.
void invalidateStats(WidgetRef ref) {
  ref
    ..invalidate(overviewProvider)
    ..invalidate(leaderboardProvider)
    ..invalidate(disciplineProvider)
    ..invalidate(disciplinesProvider)
    ..invalidate(practiceProvider);
}
