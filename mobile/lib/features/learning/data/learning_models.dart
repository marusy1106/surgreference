import '../../../core/ui/ui.dart';

/// Модели учебного контента, как их отдаёт API этапа 5. Экраны строят из них свои view-модели.
class TopicSummary {
  const TopicSummary({required this.id, required this.title, required this.lessons, required this.quizQuestions});

  final String id;
  final String title;
  final List<LessonSummary> lessons;

  /// 0 — теста по теме ещё нет.
  final int quizQuestions;
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

  final String id;
  final String title;
  final Aura aura;
  final List<TopicSummary> topics;
}

class QuizQuestion {
  const QuizQuestion({required this.id, required this.text, required this.options, this.multiple = false});

  final String id;
  final String text;
  final List<String> options;
  final bool multiple;
}

/// Попытка теста. Правильные ответы клиенту не приходят — их проверяет сервер при отправке.
class QuizSession {
  const QuizSession({
    required this.attemptId,
    required this.topic,
    required this.aura,
    required this.questions,
    this.secondsPerQuestion = 90,
  });

  final String attemptId;
  final String topic;
  final Aura aura;
  final List<QuizQuestion> questions;
  final int secondsPerQuestion;
}

class QuizReviewItem {
  const QuizReviewItem({
    required this.question,
    required this.selected,
    required this.correct,
    required this.explanation,
  });

  final QuizQuestion question;
  final Set<int> selected;
  final Set<int> correct;
  final String explanation;

  bool get isCorrect => selected.length == correct.length && selected.containsAll(correct);
}

class QuizOutcome {
  const QuizOutcome({required this.topic, required this.aura, required this.xpGained, required this.items});

  final String topic;
  final Aura aura;
  final int xpGained;
  final List<QuizReviewItem> items;

  int get score => items.where((i) => i.isCorrect).length;
}

class CaseSummary {
  const CaseSummary({required this.id, required this.title, required this.discipline, required this.aura});

  final String id;
  final String title;
  final String discipline;
  final Aura aura;
}

class CaseChoice {
  const CaseChoice(this.text, {required this.correct, required this.feedback});

  final String text;
  final bool correct;
  final String feedback;
}

class CaseStep {
  const CaseStep({
    required this.title,
    required this.situation,
    required this.prompt,
    required this.choices,
    required this.summary,
  });

  final String title;
  final String situation;
  final String prompt;
  final List<CaseChoice> choices;

  /// Краткая запись шага для «листа» пройденных шагов.
  final String summary;
}

class ClinicalCase {
  const ClinicalCase({required this.summary, required this.steps, required this.takeaway});

  final CaseSummary summary;
  final List<CaseStep> steps;

  /// Итоговый разбор: оптимальный путь и что повторить.
  final String takeaway;
}
