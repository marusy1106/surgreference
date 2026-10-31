import '../../../core/ui/ui.dart';

/// Модели учебного API (backend: apps/progress, assessment, cases, gamification, leaderboards).
/// Идентификаторы — строки: в маршрутах приложения они так и используются.

String _id(Object? v) => '$v';
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
List<Map<String, dynamic>> _list(Object? v) => [for (final e in (v as List? ?? const [])) e as Map<String, dynamic>];

class ProgressOverview {
  const ProgressOverview({
    required this.level,
    required this.totalXp,
    required this.levelXp,
    required this.nextLevelXp,
    required this.currentStreak,
    required this.weekXp,
    required this.previousWeekXp,
    required this.lessonsCompleted,
    required this.quizzesFinished,
    required this.casesFinished,
    required this.disciplines,
    this.continueLesson,
    this.weakTopic,
    this.lastQuiz,
  });

  factory ProgressOverview.fromJson(Map<String, dynamic> j) {
    final lesson = j['continue_lesson'] as Map<String, dynamic>?;
    final weak = j['weak_topic'] as Map<String, dynamic>?;
    final quiz = j['last_quiz'] as Map<String, dynamic>?;
    return ProgressOverview(
      level: j['level'] as int,
      totalXp: j['total_xp'] as int,
      levelXp: j['level_xp'] as int,
      nextLevelXp: j['next_level_xp'] as int,
      currentStreak: j['current_streak'] as int,
      weekXp: j['week_xp'] as int,
      previousWeekXp: j['previous_week_xp'] as int,
      lessonsCompleted: j['lessons_completed'] as int,
      quizzesFinished: j['quizzes_finished'] as int,
      casesFinished: j['cases_finished'] as int,
      disciplines: [for (final d in _list(j['disciplines'])) DisciplineSummary.fromJson(d)],
      continueLesson: lesson == null
          ? null
          : (
              id: _id(lesson['id']),
              title: lesson['title'] as String,
              discipline: lesson['discipline'] as String,
              aura: Aura.fromToken(lesson['palette_token'] as String?),
            ),
      weakTopic: weak == null
          ? null
          : (
              title: weak['title'] as String,
              mastery: _d(weak['mastery']),
              disciplineSlug: weak['discipline_slug'] as String,
            ),
      lastQuiz: quiz == null
          ? null
          : (
              quizId: _id(quiz['quiz_id']),
              topic: quiz['topic'] as String,
              correct: quiz['correct'] as int,
              total: quiz['total'] as int,
              aura: Aura.fromToken(quiz['palette_token'] as String?),
            ),
    );
  }

  final int level;
  final int totalXp;
  final int levelXp;
  final int nextLevelXp;
  final int currentStreak;
  final int weekXp;
  final int previousWeekXp;
  final int lessonsCompleted;
  final int quizzesFinished;
  final int casesFinished;
  final List<DisciplineSummary> disciplines;
  final ({String id, String title, String discipline, Aura aura})? continueLesson;
  final ({String title, double mastery, String disciplineSlug})? weakTopic;
  final ({String quizId, String topic, int correct, int total, Aura aura})? lastQuiz;

  /// Освоение по дисциплинам, где есть темы: среднее для плитки на главной.
  double get averageMastery {
    final withTopics = disciplines.where((d) => d.topics > 0).toList();
    if (withTopics.isEmpty) return 0;
    return withTopics.map((d) => d.mastery).reduce((a, b) => a + b) / withTopics.length;
  }
}

class DisciplineSummary {
  const DisciplineSummary({
    required this.slug,
    required this.title,
    required this.aura,
    required this.topics,
    required this.mastery,
  });

  factory DisciplineSummary.fromJson(Map<String, dynamic> j) => DisciplineSummary(
    slug: j['slug'] as String,
    title: j['title'] as String,
    aura: Aura.fromToken(j['palette_token'] as String?),
    topics: j['topics_count'] as int,
    mastery: _d(j['mastery']),
  );

  final String slug;
  final String title;
  final Aura aura;
  final int topics;
  final double mastery;
}

/// Дисциплина на вкладке «Практика»: сколько вопросов для тренировки и сколько ошибок.
class PracticeDiscipline {
  const PracticeDiscipline({
    required this.slug,
    required this.title,
    required this.aura,
    required this.questions,
    required this.mistakes,
    required this.mistakesAvailable,
  });

  factory PracticeDiscipline.fromJson(Map<String, dynamic> j) => PracticeDiscipline(
    slug: j['slug'] as String,
    title: j['title'] as String,
    aura: Aura.fromToken(j['palette_token'] as String?),
    questions: j['questions'] as int,
    mistakes: j['mistakes'] as int,
    mistakesAvailable: j['mistakes_available'] as bool,
  );

  final String slug;
  final String title;
  final Aura aura;
  final int questions;
  final int mistakes;
  final bool mistakesAvailable;
}

/// Откуда вопросы: тест темы (id — тест), тренировка или работа над ошибками (id — slug дисциплины).
enum QuizMode { topic, training, mistakes }

class TopicSummary {
  const TopicSummary({
    required this.id,
    required this.title,
    required this.lessons,
    this.quizId,
    this.quizQuestions = 0,
    this.mastery = 0,
  });

  factory TopicSummary.fromJson(Map<String, dynamic> j) {
    final quiz = j['quiz'] as Map<String, dynamic>?;
    return TopicSummary(
      id: _id(j['id']),
      title: j['title'] as String,
      mastery: _d(j['mastery']),
      quizId: quiz == null ? null : _id(quiz['id']),
      quizQuestions: quiz == null ? 0 : quiz['questions'] as int,
      lessons: [
        for (final l in _list(j['lessons']))
          LessonSummary(
            id: _id(l['id']),
            title: l['title'] as String,
            minutes: l['minutes'] as int,
            completed: l['completed'] as bool,
          ),
      ],
    );
  }

  final String id;
  final String title;
  final List<LessonSummary> lessons;
  final String? quizId;
  final int quizQuestions;
  final double mastery;
}

class LessonSummary {
  const LessonSummary({required this.id, required this.title, required this.minutes, this.completed = false});

  final String id;
  final String title;
  final int minutes;
  final bool completed;
}

class DisciplineDetail {
  const DisciplineDetail({required this.id, required this.title, required this.aura, required this.topics});

  factory DisciplineDetail.fromJson(Map<String, dynamic> j) => DisciplineDetail(
    id: j['slug'] as String,
    title: j['title'] as String,
    aura: Aura.fromToken(j['palette_token'] as String?),
    topics: [for (final t in _list(j['topics'])) TopicSummary.fromJson(t)],
  );

  final String id;
  final String title;
  final Aura aura;
  final List<TopicSummary> topics;
}

class QuizOption {
  const QuizOption(this.id, this.text);

  final String id;
  final String text;
}

class QuizQuestion {
  const QuizQuestion({required this.id, required this.text, required this.options, this.multiple = false});

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id: _id(j['id']),
    text: j['text'] as String,
    multiple: j['kind'] == 'multiple',
    options: [for (final o in _list(j['options'])) QuizOption(_id(o['id']), o['text'] as String)],
  );

  final String id;
  final String text;
  final List<QuizOption> options;
  final bool multiple;
}

/// Попытка теста. Правильные ответы клиенту не приходят — их проверяет сервер при завершении.
class QuizSession {
  const QuizSession({
    required this.attemptId,
    required this.topic,
    required this.aura,
    required this.questions,
    this.secondsPerQuestion = 90,
  });

  factory QuizSession.fromJson(Map<String, dynamic> j) {
    final quiz = j['quiz'] as Map<String, dynamic>;
    final topic = quiz['topic'] as String? ?? '';
    return QuizSession(
      attemptId: j['attempt_id'] as String,
      topic: topic.isEmpty ? quiz['title'] as String : topic,
      aura: Aura.fromToken(quiz['palette_token'] as String?),
      secondsPerQuestion: j['seconds_per_question'] as int? ?? 90,
      questions: [for (final q in _list(j['questions'])) QuizQuestion.fromJson(q)],
    );
  }

  final String attemptId;
  final String topic;
  final Aura aura;
  final List<QuizQuestion> questions;
  final int secondsPerQuestion;
}

class ReviewOption {
  const ReviewOption({required this.text, required this.isCorrect, required this.selected, required this.explanation});

  final String text;
  final bool isCorrect;
  final bool selected;
  final String explanation;
}

class QuizReviewItem {
  const QuizReviewItem({required this.text, required this.options, required this.isCorrect, required this.explanation});

  final String text;
  final List<ReviewOption> options;
  final bool isCorrect;
  final String explanation;
}

/// Итог попытки и разбор: каждый вариант с объяснением.
class QuizOutcome {
  const QuizOutcome({
    required this.topic,
    required this.aura,
    required this.xpGained,
    required this.correct,
    required this.items,
    this.lessonId,
  });

  factory QuizOutcome.fromJson(Map<String, dynamic> j) {
    final quiz = j['quiz'] as Map<String, dynamic>;
    final topic = quiz['topic'] as String? ?? '';
    return QuizOutcome(
      topic: topic.isEmpty ? quiz['title'] as String : topic,
      aura: Aura.fromToken(quiz['palette_token'] as String?),
      xpGained: j['xp_awarded'] as int,
      correct: j['correct'] as int,
      lessonId: j['lesson_id'] == null ? null : _id(j['lesson_id']),
      items: [
        for (final i in _list(j['items']))
          QuizReviewItem(
            text: i['text'] as String,
            isCorrect: i['is_correct'] as bool,
            explanation: i['explanation'] as String? ?? '',
            options: [
              for (final o in _list(i['options']))
                ReviewOption(
                  text: o['text'] as String,
                  isCorrect: o['is_correct'] as bool,
                  selected: o['selected'] as bool,
                  explanation: o['explanation'] as String? ?? '',
                ),
            ],
          ),
      ],
    );
  }

  final String topic;
  final Aura aura;
  final int xpGained;
  final int correct;
  final List<QuizReviewItem> items;
  final String? lessonId;

  int get score => correct;
}

class CaseSummary {
  const CaseSummary({
    required this.id,
    required this.title,
    required this.discipline,
    required this.aura,
    this.summary = '',
  });

  factory CaseSummary.fromJson(Map<String, dynamic> j) => CaseSummary(
    id: _id(j['id']),
    title: j['title'] as String,
    discipline: j['discipline'] as String,
    aura: Aura.fromToken(j['palette_token'] as String?),
    summary: j['summary'] as String? ?? '',
  );

  final String id;
  final String title;
  final String discipline;
  final Aura aura;
  final String summary;
}

class CaseChoice {
  const CaseChoice(this.id, this.text);

  final String id;
  final String text;
}

class CaseStep {
  const CaseStep({
    required this.id,
    required this.number,
    required this.title,
    required this.situation,
    required this.prompt,
    required this.summary,
    required this.choices,
  });

  factory CaseStep.fromJson(Map<String, dynamic> j) => CaseStep(
    id: _id(j['id']),
    number: j['number'] as int,
    title: j['title'] as String,
    situation: j['situation'] as String,
    prompt: j['prompt'] as String,
    summary: j['summary'] as String? ?? '',
    choices: [for (final c in _list(j['choices'])) CaseChoice(_id(c['id']), c['text'] as String)],
  );

  final String id;
  final int number;
  final String title;
  final String situation;
  final String prompt;
  final String summary;
  final List<CaseChoice> choices;
}

class CaseSession {
  const CaseSession({required this.attemptId, required this.summary, required this.stepTitles, required this.step});

  factory CaseSession.fromJson(Map<String, dynamic> j) => CaseSession(
    attemptId: j['attempt_id'] as String,
    summary: CaseSummary.fromJson(j['case'] as Map<String, dynamic>),
    stepTitles: [for (final t in j['step_titles'] as List) t as String],
    step: CaseStep.fromJson(j['step'] as Map<String, dynamic>),
  );

  final String attemptId;
  final CaseSummary summary;
  final List<String> stepTitles;
  final CaseStep step;
}

/// Ответ сервера на выбор: качество, обратная связь, лучший вариант, следующий шаг.
class CaseOutcome {
  const CaseOutcome({
    required this.choiceId,
    required this.isGood,
    required this.feedback,
    required this.optimalChoiceId,
    required this.finished,
    this.nextStep,
  });

  factory CaseOutcome.fromJson(Map<String, dynamic> j) => CaseOutcome(
    choiceId: _id(j['choice_id']),
    isGood: j['is_good'] as bool,
    feedback: j['feedback'] as String,
    optimalChoiceId: _id(j['optimal_choice_id']),
    finished: j['finished'] as bool,
    nextStep: j['next_step'] == null ? null : CaseStep.fromJson(j['next_step'] as Map<String, dynamic>),
  );

  final String choiceId;
  final bool isGood;
  final String feedback;
  final String optimalChoiceId;
  final bool finished;
  final CaseStep? nextStep;
}

class CaseReviewStep {
  const CaseReviewStep({
    required this.title,
    required this.chosen,
    required this.chosenGood,
    required this.feedback,
    required this.optimal,
  });

  final String title;
  final String chosen;
  final bool chosenGood;
  final String feedback;
  final String optimal;
}

class CaseReview {
  const CaseReview({
    required this.summary,
    required this.score,
    required this.xpGained,
    required this.debrief,
    required this.steps,
  });

  factory CaseReview.fromJson(Map<String, dynamic> j) => CaseReview(
    summary: CaseSummary.fromJson(j['case'] as Map<String, dynamic>),
    score: _d(j['score']),
    xpGained: j['xp_awarded'] as int,
    debrief: j['debrief'] as String? ?? '',
    steps: [
      for (final s in _list(j['steps']))
        CaseReviewStep(
          title: s['title'] as String,
          chosen: (s['chosen'] as Map)['text'] as String,
          chosenGood: (s['chosen'] as Map)['is_good'] as bool,
          feedback: (s['chosen'] as Map)['feedback'] as String,
          optimal: (s['optimal'] as Map)['text'] as String,
        ),
    ],
  );

  final CaseSummary summary;
  final double score;
  final int xpGained;
  final String debrief;
  final List<CaseReviewStep> steps;
}

class ActivityPoint {
  const ActivityPoint(this.label, this.xp);

  final String label;
  final int xp;
}

class AchievementItem {
  const AchievementItem({required this.code, required this.title, required this.icon, required this.earned});

  factory AchievementItem.fromJson(Map<String, dynamic> j) => AchievementItem(
    code: j['code'] as String,
    title: j['title'] as String,
    icon: j['icon'] as String? ?? '',
    earned: j['earned_at'] != null,
  );

  final String code;
  final String title;
  final String icon;
  final bool earned;
}

class BoardRow {
  const BoardRow({required this.rank, required this.name, required this.subtitle, required this.xp, this.isMe = false});

  final int rank;
  final String name;
  final String subtitle;
  final int xp;
  final bool isMe;
}

class Board {
  const Board({required this.rows, this.me, this.optedIn = true, this.needsUniversity = false, this.note});

  final List<BoardRow> rows;
  final BoardRow? me;
  final bool optedIn;
  final bool needsUniversity;

  /// Пояснение под таблицей (например, порог участников для вузов).
  final String? note;
}
