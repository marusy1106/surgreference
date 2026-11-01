import 'package:flutter_test/flutter_test.dart';
import 'package:surgreference/core/api/api_client.dart';
import 'package:surgreference/core/api/token_store.dart';
import 'package:surgreference/core/ui/ui.dart';
import 'package:surgreference/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:surgreference/features/learning/data/api_learning_repository.dart';
import 'package:surgreference/features/lesson/presentation/lesson_screen.dart';
import 'package:surgreference/features/references/data/references_models.dart';

import '../fake_backend.dart';

/// Разбор настоящих ответов API (test/fixtures/api записаны с dev-сервера).
void main() {
  late FakeBackend backend;
  late ApiLearningRepository repo;

  setUp(() {
    backend = FakeBackend(learningRoutes());
    repo = ApiLearningRepository(
      ApiClient(baseUrl: 'http://test/api/v1/', store: MemoryTokenStore(), adapter: backend),
    );
  });

  test('overview', () async {
    final o = await repo.overview();
    expect(o.lastQuiz!.topic, 'Острый аппендицит');
    expect(o.lastQuiz!.aura, Aura.surgery);
    expect(o.weakTopic!.mastery, 0.4);
    expect(o.disciplines, hasLength(6));
    expect(o.averageMastery, 0.4, reason: 'only disciplines with topics count');
  });

  test('lesson blocks map to screen blocks', () async {
    final lesson = await repo.lesson('1');
    expect(lesson.blocks.map((b) => b.runtimeType), [
      ParagraphBlock,
      HeadingBlock,
      BulletsBlock,
      ImportantBlock,
      TableBlock,
      HeadingBlock,
      IcdRefBlock,
      GuidelineRefBlock,
    ]);
    expect(lesson.blocks.whereType<TableBlock>().single.rows, hasLength(8));
    final ref = lesson.blocks.whereType<GuidelineRefBlock>().single;
    expect((ref.id, ref.version, ref.status, ref.revised), (1, 'демо-2', GuidelineStatus.active, false));
    expect(lesson.blocks.whereType<IcdRefBlock>().single.title, 'Острый аппендицит');
    expect(lesson.reviewer, 'демо-рецензент');
    expect(lesson.updatedAt, matches(RegExp(r'^\d{1,2} [а-я]+ \d{4}$')));
  });

  test('quiz session has option ids but no answers; outcome comes from the review', () async {
    final session = await repo.startQuiz('1');
    expect(session.questions, hasLength(5));
    expect(session.questions.last.multiple, isTrue);

    final q = session.questions.first;
    await repo.answer(session.attemptId, q.id, [q.options.first.id]);
    expect(backend.log.last, startsWith('POST attempts/$quizAttempt/answers'));

    final outcome = await repo.finishQuiz(session.attemptId);
    expect(outcome.correct, 2);
    expect(outcome.items.where((i) => i.isCorrect), hasLength(2));
    expect(outcome.items.first.options.every((o) => o.explanation.isNotEmpty), isTrue);
    expect(outcome.lessonId, '1');
  });

  test('practice: training and mistakes sessions have no topic quiz', () async {
    final practice = await repo.practice();
    expect(practice.single.slug, 'surgery');
    expect(practice.single.mistakes, 5);
    expect(practice.single.mistakesAvailable, isTrue);

    final training = await repo.startTraining('surgery');
    expect(training.attemptId, trainingAttempt);
    expect(training.topic, 'Тренировка · Хирургия');
    expect(training.aura, Aura.surgery);

    final mistakes = await repo.startMistakes('surgery');
    final outcome = await repo.finishQuiz(mistakes.attemptId);
    expect(outcome.topic, 'Работа над ошибками · Хирургия');
    expect(outcome.correct, 5);
    expect(outcome.xpGained, 10);
    expect(outcome.lessonId, isNull);
  });

  test('case flow', () async {
    final session = await repo.startCase('1');
    expect(session.stepTitles, hasLength(3));
    final outcome = await repo.chooseInCase(session.attemptId, session.step.choices[1].id);
    expect(outcome.isGood, isFalse);
    expect(outcome.nextStep!.number, 2);
    final review = await repo.caseReview(session.attemptId);
    expect(review.steps.map((s) => s.chosenGood), [false, true, true]);
    expect(review.debrief, startsWith('Оптимальный путь'));
  });

  test('leaderboard rows show level and university', () async {
    final board = await repo.leaderboard(LeaderboardMode.students, LeaderboardScope.all, 'week');
    expect(board.optedIn, isTrue);
    expect(board.me!.subtitle, 'ур. 1');
    expect(backend.log.last, 'GET leaderboards/users -');
  });
}
