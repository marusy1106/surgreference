import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../catalog/presentation/catalog_screen.dart';
import '../home/presentation/home_screen.dart';
import '../leaderboard/presentation/leaderboard_screen.dart';
import '../lesson/presentation/lesson_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../progress/presentation/progress_screen.dart';
import 'data/learning_models.dart';

final homeProvider = FutureProvider.autoDispose<HomeView>(
  (ref) => ref.watch(learningRepositoryProvider).home(ref.watch(nicknameProvider)),
);

final disciplinesProvider = FutureProvider.autoDispose<List<DisciplineCardView>>(
  (ref) => ref.watch(learningRepositoryProvider).disciplines(),
);

final disciplineProvider = FutureProvider.autoDispose.family<DisciplineDetail, String>(
  (ref, id) => ref.watch(learningRepositoryProvider).discipline(id),
);

final lessonProvider = FutureProvider.autoDispose.family<LessonView, String>(
  (ref, id) => ref.watch(learningRepositoryProvider).lesson(id),
);

final casesProvider = FutureProvider.autoDispose<List<CaseSummary>>(
  (ref) => ref.watch(learningRepositoryProvider).cases(),
);

final caseProvider = FutureProvider.autoDispose.family<ClinicalCase, String>(
  (ref, id) => ref.watch(learningRepositoryProvider).clinicalCase(id),
);

final progressProvider = FutureProvider.autoDispose.family<ProgressView, ProgressPeriod>(
  (ref, period) => ref.watch(learningRepositoryProvider).progress(period),
);

final leaderboardProvider = FutureProvider.autoDispose
    .family<(List<LeaderboardRowView>, LeaderboardRowView?), (LeaderboardMode, LeaderboardScope)>(
      (ref, args) => ref.watch(learningRepositoryProvider).leaderboard(args.$1, args.$2, ref.watch(nicknameProvider)),
    );

final profileProvider = FutureProvider.autoDispose<ProfileView>(
  (ref) => ref.watch(learningRepositoryProvider).profile(ref.watch(nicknameProvider)),
);

/// После пройденного урока, теста или кейса статистика на вкладках устарела.
void invalidateStats(WidgetRef ref) {
  ref
    ..invalidate(homeProvider)
    ..invalidate(progressProvider)
    ..invalidate(profileProvider)
    ..invalidate(leaderboardProvider)
    ..invalidate(disciplineProvider);
}
