import '../../lesson/presentation/lesson_screen.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import 'learning_models.dart';

/// Учебный контент и статистика пользователя. Все методы бросают ApiException.
abstract interface class LearningRepository {
  Future<ProgressOverview> overview();
  Future<List<DisciplineSummary>> disciplines();
  Future<DisciplineDetail> discipline(String slug);
  Future<LessonView> lesson(String id);
  Future<void> completeLesson(String id);

  Future<QuizSession> startQuiz(String quizId);
  Future<void> answer(String attemptId, String questionId, List<String> optionIds);

  /// Завершить попытку и получить разбор.
  Future<QuizOutcome> finishQuiz(String attemptId);

  Future<List<CaseSummary>> cases();
  Future<CaseSession> startCase(String id);
  Future<CaseOutcome> chooseInCase(String attemptId, String choiceId);
  Future<CaseReview> caseReview(String attemptId);

  Future<List<ActivityPoint>> activity(String period);
  Future<List<AchievementItem>> achievements();
  Future<Board> leaderboard(LeaderboardMode mode, LeaderboardScope scope, String period);
  Future<void> setLeaderboardOptIn(bool optIn);
}
