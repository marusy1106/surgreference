import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../lesson/presentation/lesson_screen.dart';
import 'learning_models.dart';
import 'learning_repository.dart';

class ApiLearningRepository implements LearningRepository {
  ApiLearningRepository(this._client);

  final ApiClient _client;

  Dio get _dio => _client.dio;

  Future<T> _get<T>(String path, T Function(dynamic json) parse, {Map<String, dynamic>? query}) async {
    try {
      final r = await _dio.get<dynamic>(path, queryParameters: query);
      return parse(r.data);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<T> _post<T>(String path, T Function(dynamic json) parse, {Object? data}) async {
    try {
      final r = await _dio.post<dynamic>(path, data: data);
      return parse(r.data);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  static Map<String, dynamic> _map(dynamic json) => json as Map<String, dynamic>;
  static List<Map<String, dynamic>> _list(dynamic json) => [for (final e in json as List) e as Map<String, dynamic>];

  @override
  Future<ProgressOverview> overview() => _get('me/progress', (j) => ProgressOverview.fromJson(_map(j)));

  @override
  Future<List<DisciplineSummary>> disciplines() =>
      _get('disciplines', (j) => [for (final d in _list(j)) DisciplineSummary.fromJson(d)]);

  @override
  Future<DisciplineDetail> discipline(String slug) =>
      _get('disciplines/$slug', (j) => DisciplineDetail.fromJson(_map(j)));

  @override
  Future<LessonView> lesson(String id) => _get('lessons/$id', (j) => lessonFromJson(_map(j)));

  @override
  Future<void> completeLesson(String id) => _post('lessons/$id/complete', (_) {});

  @override
  Future<QuizSession> startQuiz(String quizId) =>
      _post('quizzes/$quizId/attempts', (j) => QuizSession.fromJson(_map(j)));

  @override
  Future<void> answer(String attemptId, String questionId, List<String> optionIds) => _post(
    'attempts/$attemptId/answers',
    (_) {},
    data: {
      'question_id': int.parse(questionId),
      'option_ids': [for (final id in optionIds) int.parse(id)],
    },
  );

  @override
  Future<QuizOutcome> finishQuiz(String attemptId) async {
    await _post('attempts/$attemptId/finish', (_) {});
    return _get('attempts/$attemptId/review', (j) => QuizOutcome.fromJson(_map(j)));
  }

  @override
  Future<List<CaseSummary>> cases() => _get('cases', (j) => [for (final c in _list(j)) CaseSummary.fromJson(c)]);

  @override
  Future<CaseSession> startCase(String id) => _post('cases/$id/attempts', (j) => CaseSession.fromJson(_map(j)));

  @override
  Future<CaseOutcome> chooseInCase(String attemptId, String choiceId) => _post(
    'case-attempts/$attemptId/choices',
    (j) => CaseOutcome.fromJson(_map(j)),
    data: {'choice_id': int.parse(choiceId)},
  );

  @override
  Future<CaseReview> caseReview(String attemptId) =>
      _get('case-attempts/$attemptId/review', (j) => CaseReview.fromJson(_map(j)));

  @override
  Future<List<ActivityPoint>> activity(String period) => _get(
    'me/activity',
    (j) => [for (final p in _list(_map(j)['points'])) ActivityPoint(p['label'] as String, p['xp'] as int)],
    query: {'period': period},
  );

  @override
  Future<List<AchievementItem>> achievements() =>
      _get('me/achievements', (j) => [for (final a in _list(j)) AchievementItem.fromJson(a)]);

  @override
  Future<Board> leaderboard(LeaderboardMode mode, LeaderboardScope scope, String period) {
    if (mode == LeaderboardMode.universities) {
      return _get('leaderboards/universities', query: {'period': period}, (j) {
        final body = _map(j);
        return Board(
          note:
              'Балл вуза — среднее XP на активного участника. В рейтинг попадают вузы, где участников '
              'не меньше ${body['min_participants']}.',
          rows: [
            for (final r in _list(body['rows']))
              BoardRow(
                rank: r['rank'] as int,
                name: r['name'] as String,
                subtitle: '${r['participants']} участников',
                xp: (r['score'] as num).round(),
              ),
          ],
        );
      });
    }
    return _get(
      'leaderboards/users',
      query: {'period': period, 'scope': scope == LeaderboardScope.all ? 'global' : 'university'},
      (j) {
        final body = _map(j);
        BoardRow row(Map<String, dynamic> r) => BoardRow(
          rank: r['rank'] as int,
          name: r['display_name'] as String,
          subtitle: ['ур. ${r['level']}', ?r['university'] as String?].join(' · '),
          xp: r['xp'] as int,
          isMe: r['is_me'] as bool,
        );
        return Board(
          rows: [for (final r in _list(body['rows'])) row(r)],
          me: body['me'] == null ? null : row(_map(body['me'])),
          optedIn: body['opted_in'] as bool,
          needsUniversity: body['needs_university'] as bool,
        );
      },
    );
  }

  @override
  Future<void> setLeaderboardOptIn(bool optIn) async {
    try {
      await _dio.put<void>('me/leaderboard-participation', data: {'opt_in': optIn});
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

/// Блоки урока из API (heading, paragraph, list, callout, table) → блоки экрана. Неизвестный тип с текстом
/// показывается абзацем: старое приложение не теряет содержимое новых блоков.
LessonView lessonFromJson(Map<String, dynamic> j) {
  final blocks = <LessonBlock>[];
  for (final raw in j['body'] as List) {
    final b = raw as Map<String, dynamic>;
    final text = b['text'] as String? ?? '';
    switch (b['type']) {
      case 'heading':
        blocks.add(HeadingBlock(text));
      case 'list':
        blocks.add(BulletsBlock([for (final i in b['items'] as List) '$i']));
      case 'callout':
        blocks.add(ImportantBlock(text));
      case 'table':
        blocks.add(
          TableBlock(
            caption: b['caption'] as String?,
            header: [for (final h in b['header'] as List) '$h'],
            rows: [
              for (final r in b['rows'] as List) [for (final c in r as List) '$c'],
            ],
          ),
        );
      default:
        if (text.isNotEmpty) blocks.add(ParagraphBlock(text));
    }
  }
  final published = DateTime.tryParse(j['published_at'] as String? ?? '')?.toLocal();
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  return LessonView(
    discipline: j['discipline'] as String,
    topic: j['topic'] as String,
    title: j['title'] as String,
    readMinutes: j['estimated_minutes'] as int,
    blocks: blocks,
    sources: [for (final s in j['sources'] as List) '$s'],
    reviewer: j['reviewer'] as String,
    updatedAt: published == null ? '' : '${published.day} ${months[published.month - 1]} ${published.year}',
  );
}
