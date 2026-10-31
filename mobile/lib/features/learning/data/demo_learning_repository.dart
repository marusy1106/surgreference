import '../../../core/ui/ui.dart';
import '../../../design_preview/demo_data.dart';
import '../../catalog/presentation/catalog_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../lesson/presentation/lesson_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../progress/presentation/progress_screen.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

/// Демо-контент до появления API контента. Логика как у сервера: ответы проверяются здесь, клиенту
/// при старте теста не отдаются; XP и пройденные уроки копятся в памяти до перезапуска.
class DemoLearningRepository implements LearningRepository {
  DemoLearningRepository({this.latency = const Duration(milliseconds: 250)});

  final Duration latency;
  final _completedLessons = <String>{};
  var _xpGained = 0;
  var _attempts = 0;
  final _openAttempts = <String, String>{};

  static const _xpPerCorrect = 5;

  Future<T> _delay<T>(T value) => Future.delayed(latency, () => value);

  @override
  bool get isDemo => true;

  @override
  Future<HomeView> home(String nickname) {
    const h = Demo.home;
    return _delay(
      HomeView(
        nickname: nickname,
        continueLesson: h.continueLesson,
        lastQuiz: h.lastQuiz,
        caseOfDay: h.caseOfDay,
        streakDays: h.streakDays,
        streakGoal: h.streakGoal,
        weekXp: h.weekXp + _xpGained,
        weekXpDelta: h.weekXpDelta + _xpGained,
        mastery: h.mastery,
        weakTopic: h.weakTopic,
      ),
    );
  }

  @override
  Future<List<DisciplineCardView>> disciplines() => _delay(Demo.disciplines);

  @override
  Future<DisciplineDetail> discipline(String id) {
    final card = Demo.disciplines.firstWhere((d) => d.id == id, orElse: () => throw StateError('discipline $id'));
    final topics = id == 'surgery'
        ? [
            TopicSummary(
              id: _appendicitisTopic,
              title: 'Острый аппендицит',
              quizQuestions: _questions.length,
              lessons: [
                LessonSummary(
                  id: _appendicitisLesson,
                  title: Demo.lesson.title,
                  minutes: Demo.lesson.readMinutes,
                  completed: _completedLessons.contains(_appendicitisLesson),
                ),
              ],
            ),
            const TopicSummary(id: 'cholecystitis', title: 'Острый холецистит', lessons: [], quizQuestions: 0),
            const TopicSummary(id: 'hernia', title: 'Ущемлённая грыжа', lessons: [], quizQuestions: 0),
          ]
        : const <TopicSummary>[];
    return _delay(DisciplineDetail(id: id, title: card.title, aura: card.aura, topics: topics));
  }

  @override
  Future<LessonView> lesson(String id) =>
      id == _appendicitisLesson ? _delay(Demo.lesson) : Future.error(StateError('lesson $id'));

  @override
  Future<void> completeLesson(String id) async {
    await _delay(null);
    if (_completedLessons.add(id)) _xpGained += 10;
  }

  @override
  Future<QuizSession> startQuiz(String topicId) async {
    await _delay(null);
    if (topicId != _appendicitisTopic) throw StateError('quiz $topicId');
    final attemptId = 'demo-${++_attempts}';
    _openAttempts[attemptId] = topicId;
    return QuizSession(
      attemptId: attemptId,
      topic: 'Острый аппендицит',
      aura: Aura.surgery,
      questions: [for (final q in _questions) q.question],
    );
  }

  @override
  Future<QuizOutcome> submitQuiz(String attemptId, Map<String, Set<int>> answers) async {
    await _delay(null);
    if (_openAttempts.remove(attemptId) == null) throw StateError('attempt $attemptId is closed');
    final items = [
      for (final q in _questions)
        QuizReviewItem(
          question: q.question,
          selected: answers[q.question.id] ?? const {},
          correct: q.correct,
          explanation: q.explanation,
        ),
    ];
    final xp = items.where((i) => i.isCorrect).length * _xpPerCorrect;
    _xpGained += xp;
    return QuizOutcome(topic: 'Острый аппендицит', aura: Aura.surgery, xpGained: xp, items: items);
  }

  @override
  Future<List<CaseSummary>> cases() => _delay([_case.summary]);

  @override
  Future<ClinicalCase> clinicalCase(String id) =>
      id == _case.summary.id ? _delay(_case) : Future.error(StateError('case $id'));

  @override
  Future<ProgressView> progress(ProgressPeriod period) {
    const p = Demo.progress;
    final (values, labels) = switch (period) {
      ProgressPeriod.week => (const <double>[40, 85, 60, 120, 95, 30, 140], const ['пн', 'ср', 'пт', 'вс']),
      ProgressPeriod.month => (p.activity, p.activityLabels),
      ProgressPeriod.year => (
        const <double>[300, 420, 380, 510, 640, 590, 720, 680, 910, 1040, 1180, 1320],
        const ['янв', 'апр', 'июл', 'окт'],
      ),
    };
    return _delay(
      ProgressView(
        period: period,
        level: p.level,
        xpInLevel: (p.xpInLevel + _xpGained).clamp(0, p.xpForLevel),
        xpForLevel: p.xpForLevel,
        activity: values,
        activityLabels: labels,
        activitySummary: 'Демо-данные: активность растёт к концу периода.',
        mastery: p.mastery,
        lessons: p.lessons + _completedLessons.length,
        quizzes: p.quizzes + _attempts,
        cases: p.cases,
      ),
    );
  }

  @override
  Future<(List<LeaderboardRowView>, LeaderboardRowView?)> leaderboard(
    LeaderboardMode mode,
    LeaderboardScope scope,
    String nickname,
  ) {
    if (mode == LeaderboardMode.universities) {
      return _delay((
        const [
          LeaderboardRowView(rank: 1, name: 'Демо-медуниверситет №1', subtitle: '128 участников', xp: 48210),
          LeaderboardRowView(rank: 2, name: 'Демо-медуниверситет №2', subtitle: '96 участников', xp: 40105),
          LeaderboardRowView(rank: 3, name: 'Демо-медуниверситет №3', subtitle: '71 участник', xp: 33980),
        ],
        null,
      ));
    }
    final me = LeaderboardRowView(
      rank: scope == LeaderboardScope.all ? 214 : Demo.me.rank,
      name: nickname,
      subtitle: Demo.me.subtitle,
      xp: Demo.me.xp + _xpGained,
      isMe: true,
    );
    return _delay((Demo.leaderboard, me));
  }

  @override
  Future<ProfileView> profile(String nickname) {
    const p = Demo.profile;
    return _delay(
      ProfileView(
        nickname: nickname,
        level: p.level,
        xpTotal: p.xpTotal + _xpGained,
        status: p.status,
        university: p.university,
        achievements: p.achievements,
      ),
    );
  }
}

const _appendicitisTopic = 'appendicitis';
const _appendicitisLesson = 'appendicitis-diagnosis';

class _KeyedQuestion {
  const _KeyedQuestion(this.question, this.correct, this.explanation);

  final QuizQuestion question;
  final Set<int> correct;
  final String explanation;
}

const _questions = [
  _KeyedQuestion(
    QuizQuestion(
      id: 'q1',
      text: 'Как называется смещение боли из эпигастрия в правую подвздошную область?',
      options: ['Симптом Кохера', 'Симптом Ровзинга', 'Симптом Щёткина — Блюмберга', 'Симптом Ортнера'],
    ),
    {0},
    'Симптом Кохера (Кохера — Волковича) — миграция боли из эпигастрия в правую подвздошную область в первые '
    'часы заболевания. Симптом Ортнера относится к острому холециститу.',
  ),
  _KeyedQuestion(
    QuizQuestion(
      id: 'q2',
      text: 'Что такое симптом Ровзинга?',
      options: [
        'Боль справа при толчкообразном давлении в левой подвздошной области',
        'Усиление боли при резком отнятии руки от брюшной стенки',
        'Усиление боли в положении на левом боку',
        'Боль при поднятии выпрямленной правой ноги',
      ],
    ),
    {0},
    'Ровзинг — боль в правой подвздошной области при толчкообразном давлении слева. Второй вариант — симптом '
    'Щёткина — Блюмберга, третий — Ситковского, четвёртый — Образцова.',
  ),
  _KeyedQuestion(
    QuizQuestion(
      id: 'q3',
      text: 'Какой метод визуализации выбирают первым при подозрении на аппендицит у беременной?',
      options: ['КТ брюшной полости с контрастированием', 'УЗИ брюшной полости', 'Обзорная рентгенография'],
    ),
    {1},
    'УЗИ — метод первой линии: нет лучевой нагрузки на плод. Если УЗИ не дало ответа, следующим выполняют МРТ '
    'без контрастирования. КТ у беременных применяют ограниченно.',
  ),
  _KeyedQuestion(
    QuizQuestion(id: 'q4', text: 'Сколько баллов шкалы Альварадо даёт лейкоцитоз?', options: ['1', '2', '3']),
    {1},
    'Лейкоцитоз и болезненность в правой подвздошной области — по 2 балла, остальные шесть признаков — по 1. '
    'Максимум — 10 баллов.',
  ),
  _KeyedQuestion(
    QuizQuestion(
      id: 'q5',
      text: 'Какие признаки входят в шкалу Альварадо?',
      multiple: true,
      options: ['Миграция боли в правую подвздошную область', 'Брадикардия', 'Тошнота или рвота', 'Лейкоцитоз'],
    ),
    {0, 2, 3},
    'В шкалу входят миграция боли, анорексия, тошнота или рвота, болезненность справа внизу, симптом раздражения '
    'брюшины, температура выше 37,3 °C, лейкоцитоз и сдвиг формулы влево. Частота пульса в неё не входит.',
  ),
];

const _case = ClinicalCase(
  summary: CaseSummary(
    id: 'rlq-pain',
    title: 'Боль в правой подвздошной области',
    discipline: 'Хирургия',
    aura: Aura.therapy,
  ),
  takeaway:
      'Оптимальный путь: осмотр и термометрия → общий анализ крови и УЗИ → госпитализация и аппендэктомия, '
      'предпочтительно лапароскопическая. Повторите урок «Острый аппендицит: клиническая картина и диагностика».',
  steps: [
    CaseStep(
      title: 'Жалобы и анамнез',
      situation:
          'Вымышленный пациент, 24 года. С вечера тупая боль около пупка, к утру сместилась в правую подвздошную '
          'область. Тошнота, однократная рвота.',
      prompt: 'С чего начнёте?',
      summary: 'Боль около пупка с вечера, к утру сместилась вправо вниз. Тошнота, рвота.',
      choices: [
        CaseChoice(
          'Осмотр живота и измерение температуры',
          correct: true,
          feedback: 'Миграция боли с тошнотой — типичное начало аппендицита. Следующий шаг — объективный осмотр.',
        ),
        CaseChoice(
          'Отпустить домой под наблюдение',
          correct: false,
          feedback: 'Картина типична для острого аппендицита: без осмотра отпускать нельзя.',
        ),
        CaseChoice(
          'Сразу направить на гастроскопию',
          correct: false,
          feedback: 'Жалобы указывают на правую подвздошную область, а не на верхние отделы ЖКТ.',
        ),
      ],
    ),
    CaseStep(
      title: 'Осмотр',
      situation:
          'Температура 37,8 °C. Болезненность и напряжение мышц в правой подвздошной области, симптом '
          'Щёткина — Блюмберга положителен.',
      prompt: 'Какое обследование назначите?',
      summary: 'Температура 37,8 °C, болезненность справа внизу, симптом Щёткина — Блюмберга +.',
      choices: [
        CaseChoice(
          'Общий анализ крови и УЗИ брюшной полости',
          correct: true,
          feedback: 'Анализ крови и УЗИ подтверждают диагноз и помогают исключить другую патологию.',
        ),
        CaseChoice(
          'Колоноскопию',
          correct: false,
          feedback: 'При подозрении на острый аппендицит колоноскопия не показана: она не помогает диагнозу.',
        ),
        CaseChoice(
          'Только ЭКГ',
          correct: false,
          feedback: 'ЭКГ не ответит на главный вопрос — есть ли острая хирургическая патология.',
        ),
      ],
    ),
    CaseStep(
      title: 'Обследование',
      situation:
          'Лейкоциты 14 × 10⁹/л, сдвиг формулы влево. На УЗИ — несжимаемый червеобразный отросток диаметром 9 мм.',
      prompt: 'Ваше решение?',
      summary: 'Лейкоцитоз со сдвигом влево, на УЗИ — утолщённый несжимаемый отросток.',
      choices: [
        CaseChoice(
          'Госпитализация в хирургию и аппендэктомия',
          correct: true,
          feedback: 'Диагноз подтверждён — показана операция. Лапароскопический доступ предпочтителен.',
        ),
        CaseChoice(
          'Антибиотики амбулаторно',
          correct: false,
          feedback: 'Консервативное лечение обсуждают только в стационаре и у отобранных пациентов.',
        ),
        CaseChoice(
          'Повторить УЗИ через неделю',
          correct: false,
          feedback: 'Отсрочка при остром аппендиците повышает риск перфорации и перитонита.',
        ),
      ],
    ),
  ],
);
