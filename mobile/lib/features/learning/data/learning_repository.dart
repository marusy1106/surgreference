import '../../catalog/presentation/catalog_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../lesson/presentation/lesson_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../progress/presentation/progress_screen.dart';
import 'learning_models.dart';

/// Учебный контент и статистика. Сейчас — [DemoLearningRepository]; реализация поверх API
/// появится вместе с эндпоинтами контента, тестов и прогресса на бэкенде (этап 5).
abstract interface class LearningRepository {
  /// Данные не с сервера: экраны показывают пометку «демо».
  bool get isDemo;

  Future<HomeView> home(String nickname);
  Future<List<DisciplineCardView>> disciplines();
  Future<DisciplineDetail> discipline(String id);
  Future<LessonView> lesson(String id);
  Future<void> completeLesson(String id);

  Future<QuizSession> startQuiz(String topicId);
  Future<QuizOutcome> submitQuiz(String attemptId, Map<String, Set<int>> answers);

  Future<List<CaseSummary>> cases();
  Future<ClinicalCase> clinicalCase(String id);

  Future<ProgressView> progress(ProgressPeriod period);
  Future<(List<LeaderboardRowView>, LeaderboardRowView?)> leaderboard(
    LeaderboardMode mode,
    LeaderboardScope scope,
    String nickname,
  );
  Future<ProfileView> profile(String nickname);
}
