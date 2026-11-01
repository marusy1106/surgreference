// Демо-данные для макетов этапа 4. Все люди и кейсы вымышлены; на этапе 5 экраны получают данные из API.
import 'package:flutter/material.dart';

import '../core/ui/ui.dart';
import '../features/cases/presentation/case_step_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/lesson/presentation/lesson_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/quiz/presentation/quiz_result_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/references/data/references_models.dart';

abstract final class Demo {
  static const nickname = 'scalpel_anna';

  static const home = HomeView(
    nickname: nickname,
    continueLesson: (
      id: 'appendicitis-diagnosis',
      discipline: 'Хирургия',
      title: 'Острый аппендицит: диагностика',
      progress: 0.6,
      aura: Aura.surgery,
    ),
    lastQuiz: (topicId: 'appendicitis', topic: 'Острый аппендицит', score: 8, total: 10, aura: Aura.neurology),
    caseOfDay: (id: 'rlq-pain', title: 'Боль в правой подвздошной области', discipline: 'Хирургия', aura: Aura.therapy),
    streakDays: 12,
    streakGoal: 30,
    weekXp: 340,
    weekXpDelta: 85,
    mastery: 0.42,
    weakTopic: 'Антибиотики: β-лактамы',
  );

  static const disciplines = [
    DisciplineCardView(id: 'surgery', title: 'Хирургия', aura: Aura.surgery, topics: 24, mastery: 0.42),
    DisciplineCardView(id: 'therapy', title: 'Терапия', aura: Aura.therapy, topics: 31, mastery: 0.18),
    DisciplineCardView(id: 'cardiology', title: 'Кардиология', aura: Aura.cardiology, topics: 12, mastery: 0.05),
    DisciplineCardView(id: 'neurology', title: 'Неврология', aura: Aura.neurology, topics: 14, mastery: 0),
    DisciplineCardView(id: 'pediatrics', title: 'Педиатрия', aura: Aura.pediatrics, topics: 21, mastery: 0.71),
    DisciplineCardView(id: 'pharmacology', title: 'Фармакология', aura: Aura.pharmacology, topics: 18, mastery: 0.33),
  ];

  static const lesson = LessonView(
    discipline: 'Хирургия',
    topic: 'Острый живот',
    title: 'Острый аппендицит: клиническая картина и диагностика',
    readMinutes: 7,
    updatedAt: '12 октября 2026',
    reviewer: 'демо-рецензент, врач-хирург',
    sources: [
      'Клинические рекомендации Минздрава России «Острый аппендицит у взрослых».',
      'МКБ-10: K35 — Острый аппендицит.',
    ],
    blocks: [
      ParagraphBlock(
        'Острый аппендицит — самое частое острое хирургическое заболевание органов брюшной полости. '
        'Диагноз ставится прежде всего клинически, инструментальные методы его подтверждают.',
      ),
      HeadingBlock('Типичная клиническая картина'),
      BulletsBlock([
        'Боль начинается в эпигастрии или около пупка и через несколько часов смещается в правую подвздошную область '
            '(симптом Кохера).',
        'Тошнота, однократная рвота, снижение аппетита.',
        'Субфебрильная температура, умеренный лейкоцитоз.',
      ]),
      ImportantBlock(
        'У беременных, пожилых и детей картина часто стёрта. Сомнение в диагнозе — повод для динамического '
        'наблюдения и визуализации, а не для назначения анальгетиков «на всякий случай».',
      ),
      TableBlock(
        caption: 'Шкала Альварадо',
        header: ['Признак', 'Баллы'],
        rows: [
          ['Миграция боли в правую подвздошную область', '1'],
          ['Анорексия', '1'],
          ['Тошнота или рвота', '1'],
          ['Болезненность в правой подвздошной области', '2'],
          ['Симптом раздражения брюшины', '1'],
          ['Температура выше 37,3 °C', '1'],
          ['Лейкоцитоз', '2'],
          ['Сдвиг лейкоцитарной формулы влево', '1'],
        ],
      ),
      HeadingBlock('Справочники'),
      IcdRefBlock(code: 'K35', title: 'Острый аппендицит'),
      GuidelineRefBlock(
        id: 1,
        title: 'Острый аппендицит у взрослых',
        version: 'демо-2',
        status: GuidelineStatus.active,
        revised: false,
      ),
    ],
  );

  static const icdSearch = [
    IcdCode(code: 'K35', title: 'Острый аппендицит', isLeaf: false),
    IcdCode(code: 'K35.2', title: 'Острый аппендицит с генерализованным перитонитом'),
    IcdCode(code: 'K35.3', title: 'Острый аппендицит с локализованным перитонитом'),
    IcdCode(code: 'K35.8', title: 'Острый аппендицит, другой и неуточненный'),
  ];

  static final appendicitisGuideline = GuidelineBrief(
    id: 1,
    title: 'Острый аппендицит у взрослых',
    status: GuidelineStatus.active,
    icdCodes: const ['K35', 'K36', 'K37'],
    version: 'демо-2',
    approvedAt: DateTime(2024),
    revisionDue: DateTime(2027),
  );

  static final guidelines = [
    appendicitisGuideline,
    GuidelineBrief(
      id: 3,
      title: 'Острый панкреатит',
      status: GuidelineStatus.active,
      icdCodes: const ['K85'],
      version: 'демо-1',
      approvedAt: DateTime(2024, 3),
      revisionDue: DateTime(2027, 3),
    ),
    GuidelineBrief(
      id: 2,
      title: 'Острый холецистит',
      status: GuidelineStatus.underRevision,
      icdCodes: const ['K80', 'K81.0'],
      version: 'демо-1',
      approvedAt: DateTime(2021, 6),
      revisionDue: DateTime(2024, 6),
    ),
  ];

  static final icdCode = IcdCodeDetail(
    code: const IcdCode(code: 'K35', title: 'Острый аппендицит', isLeaf: false),
    ancestors: const [
      IcdCode(code: 'K00-K93', title: 'Класс XI. Болезни органов пищеварения', isLeaf: false),
      IcdCode(code: 'K35-K38', title: 'Болезни аппендикса [червеобразного отростка]', isLeaf: false),
    ],
    children: icdSearch.skip(1).toList(),
    guidelines: [appendicitisGuideline],
  );

  static final guideline = GuidelineDetail(
    brief: appendicitisGuideline,
    developer: 'Российское общество хирургов',
    summary: const [
      'Демо-данные для разработки: номер версии и даты условные.',
      'Диагноз устанавливается по клинической картине, лабораторным данным и результатам визуализации '
          '(УЗИ, КТ по показаниям).',
      'Для оценки вероятности аппендицита используются шкалы (Альварадо, AIR).',
      'Основной метод лечения — аппендэктомия, предпочтительно лапароскопическая.',
    ],
    sourceUrl: 'https://cr.minzdrav.gov.ru/',
    icd: const [
      IcdCode(code: 'K35', title: 'Острый аппендицит', isLeaf: false),
      IcdCode(code: 'K36', title: 'Другие формы аппендицита'),
      IcdCode(code: 'K37', title: 'Аппендицит неуточненный'),
    ],
    versions: [
      GuidelineVersionRow(version: 'демо-2', approvedAt: DateTime(2024), current: true),
      GuidelineVersionRow(version: 'демо-1', approvedAt: DateTime(2021), current: false),
    ],
    lessons: const [CitingLesson(id: 1, title: 'Острый аппендицит: клиническая картина и диагностика')],
  );

  static const quizQuestion = QuizQuestionView(
    index: 2,
    total: 10,
    topic: 'Острый аппендицит',
    aura: Aura.surgery,
    text: 'Как называется смещение боли из эпигастрия в правую подвздошную область?',
    options: ['Симптом Кохера', 'Симптом Ровзинга', 'Симптом Щёткина — Блюмберга', 'Симптом Ортнера'],
    selected: {0},
    timeLeft: Duration(seconds: 47),
    timeLimit: Duration(seconds: 90),
  );

  static const quizResult = QuizResultView(
    topic: 'Острый аппендицит',
    aura: Aura.surgery,
    score: 8,
    total: 10,
    xpGained: 40,
    items: [
      ResultItemView(
        question: 'Как называется смещение боли из эпигастрия в правую подвздошную область?',
        correct: true,
      ),
      ResultItemView(
        question: 'Какой метод визуализации выбирают первым при подозрении на аппендицит у беременной?',
        correct: false,
        options: [
          ('КТ брюшной полости с контрастированием', AnswerState.incorrect),
          ('УЗИ брюшной полости', AnswerState.missedCorrect),
          ('Обзорная рентгенография', AnswerState.idle),
        ],
        explanation:
            'УЗИ — метод первой линии: нет лучевой нагрузки на плод. Если УЗИ не дало ответа, следующим '
            'выполняют МРТ без контрастирования. КТ у беременных применяют ограниченно.',
      ),
      ResultItemView(question: 'Сколько баллов шкалы Альварадо даёт лейкоцитоз?', correct: true),
    ],
  );

  static const caseStep = CaseStepView(
    title: 'Боль в правой подвздошной области',
    aura: Aura.therapy,
    steps: ['Жалобы и анамнез', 'Осмотр', 'Обследование', 'Решение'],
    current: 2,
    history: [
      ('Жалобы и анамнез', 'Вымышленный пациент, 24 года. Боль около пупка с вечера, к утру сместилась вправо вниз.'),
      ('Осмотр', 'Температура 37,8 °C, болезненность в правой подвздошной области, симптом Щёткина — Блюмберга +.'),
    ],
    situation: 'Лейкоциты 14 × 10⁹/л. Живот при пальпации напряжён справа внизу.',
    prompt: 'Что делаете дальше?',
    choices: [
      ('УЗИ брюшной полости и консультация хирурга', true),
      ('Отпустить домой под наблюдение', false),
      ('Плановая колоноскопия', false),
    ],
    chosen: 0,
    feedback:
        'Анализ крови и УЗИ подтверждают диагноз и помогают исключить другую патологию. '
        'Отпускать пациента с такой картиной без осмотра хирурга нельзя.',
  );

  static const progress = ProgressView(
    period: ProgressPeriod.month,
    level: 7,
    xpInLevel: 620,
    xpForLevel: 1000,
    activity: [40, 85, 60, 120, 95, 30, 140, 110, 70, 160, 135, 190],
    activityLabels: ['1 окт', '8 окт', '15 окт', '22 окт', '29 окт'],
    activitySummary: 'Активность за месяц растёт: от 40 до 190 XP в день, максимум — сегодня.',
    mastery: [
      ('Педиатрия', 0.71, Aura.pediatrics),
      ('Хирургия', 0.42, Aura.surgery),
      ('Фармакология', 0.33, Aura.pharmacology),
      ('Терапия', 0.18, Aura.therapy),
    ],
    lessons: 23,
    quizzes: 17,
    cases: 4,
  );

  static const leaderboard = [
    LeaderboardRowView(rank: 1, name: 'mitral_valve', subtitle: '5 курс · лечебный', xp: 1240),
    LeaderboardRowView(rank: 2, name: 'dr_house_fan', subtitle: '6 курс · лечебный', xp: 1105),
    LeaderboardRowView(rank: 3, name: 'kocher', subtitle: '4 курс · педиатрический', xp: 980),
    LeaderboardRowView(rank: 4, name: 'neuron42', subtitle: '5 курс · лечебный', xp: 860),
    LeaderboardRowView(rank: 5, name: 'aorta', subtitle: 'ординатура, 1 год', xp: 790),
  ];

  static const me = LeaderboardRowView(rank: 14, name: nickname, subtitle: '5 курс · лечебный', xp: 340, isMe: true);

  static const profile = ProfileView(
    nickname: nickname,
    level: 7,
    xpTotal: 6620,
    status: 'Студент, 5 курс',
    university: 'Демо-медуниверситет · лечебный',
    achievements: [
      AchievementView(title: 'Первый тест', icon: Icons.flag_rounded, unlocked: true),
      AchievementView(title: '7 дней подряд', icon: Icons.local_fire_department_rounded, unlocked: true),
      AchievementView(title: 'Без ошибок', icon: Icons.verified_rounded, unlocked: true),
      AchievementView(title: 'Первый кейс', icon: Icons.medical_services_rounded, unlocked: true),
      AchievementView(title: '30 дней подряд', icon: Icons.whatshot_rounded, unlocked: false),
      AchievementView(title: 'Знаток МКБ', icon: Icons.tag_rounded, unlocked: false),
      AchievementView(title: '100 тестов', icon: Icons.emoji_events_rounded, unlocked: false),
    ],
  );
}
