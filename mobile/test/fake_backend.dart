import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef Handler = FakeResponse Function(RequestOptions request, Map<String, dynamic>? body);

class FakeResponse {
  const FakeResponse(this.status, [this.body]);

  final int status;
  final Object? body;
}

/// Подменный бэкенд для dio: маршрут «МЕТОД путь» → обработчик. Пишет журнал запросов.
class FakeBackend implements HttpClientAdapter {
  FakeBackend(this.routes);

  final Map<String, Handler> routes;
  final log = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    log.add('$key ${options.headers['Authorization'] ?? '-'}');
    final handler = routes[key];
    if (handler == null) throw StateError('No fake route for $key');
    Map<String, dynamic>? body;
    if (requestStream != null) {
      final bytes = await requestStream.expand((chunk) => chunk).toList();
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    }
    final response = handler(options, body);
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> userJson({bool verified = true, String nickname = 'scalpel_anna'}) => {
  'id': '7d8f0f9e-0000-4000-8000-000000000001',
  'email': 'anna@example.org',
  'email_verified': verified,
  'display_name': nickname,
  'first_name': '',
  'leaderboard_opt_in': false,
  'founder_number': null,
  'created_at': '2026-10-01T10:00:00Z',
};

Map<String, dynamic> tokenPair(String access, String refresh, {bool verified = true}) => {
  'access': access,
  'refresh': refresh,
  'token_type': 'Bearer',
  'expires_in': 900,
  'session_id': '7d8f0f9e-0000-4000-8000-0000000000aa',
  'user': userJson(verified: verified),
};

const unauthorized = FakeResponse(401, {
  'error': {'code': 'token_invalid', 'message': 'Токен недействителен или истёк'},
});

/// Настоящий ответ API, записанный с dev-сервера (test/fixtures/api).
Object fixture(String name) => jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync()) as Object;

const quizAttempt = 'e6640cc2-b66d-4403-9223-fab7f993a25c';
const caseAttempt = '90bc3c45-fd6e-4d06-84e2-6653efb69444';

/// Учебные эндпоинты на записанных ответах. Выборы в кейсе отдаются по очереди, как шли при записи.
Map<String, Handler> learningRoutes({bool newUser = false}) {
  var caseChoice = 0;
  return {
    'GET me/progress': (_, _) => FakeResponse(200, fixture(newUser ? 'me_progress_new' : 'me_progress')),
    'GET cases': (_, _) => FakeResponse(200, fixture('cases')),
    'GET disciplines': (_, _) => FakeResponse(200, fixture('disciplines')),
    'GET disciplines/surgery': (_, _) => FakeResponse(200, fixture('discipline_surgery')),
    'GET lessons/1': (_, _) => FakeResponse(200, fixture('lesson')),
    'POST lessons/1/complete': (_, _) => const FakeResponse(200, {'completed': true, 'first_time': true}),
    'POST quizzes/1/attempts': (_, _) => FakeResponse(201, fixture('quiz_start')),
    'POST attempts/$quizAttempt/answers': (_, _) => const FakeResponse(204),
    'POST attempts/$quizAttempt/finish': (_, _) => FakeResponse(200, fixture('quiz_finish')),
    'GET attempts/$quizAttempt/review': (_, _) => FakeResponse(200, fixture('quiz_review')),
    'POST cases/1/attempts': (_, _) {
      caseChoice = 0;
      return FakeResponse(201, fixture('case_start'));
    },
    'POST case-attempts/$caseAttempt/choices': (_, _) => FakeResponse(200, fixture('case_choice_${caseChoice++}')),
    'GET case-attempts/$caseAttempt/review': (_, _) => FakeResponse(200, fixture('case_review')),
    'GET me/activity': (_, _) => FakeResponse(200, fixture('activity_week')),
    'GET me/achievements': (_, _) => FakeResponse(200, fixture('achievements')),
    'GET leaderboards/users': (_, _) => FakeResponse(200, fixture('board_users')),
    'GET leaderboards/universities': (_, _) => FakeResponse(200, fixture('board_universities')),
    'PUT me/leaderboard-participation': (_, body) => FakeResponse(200, body),
  };
}
