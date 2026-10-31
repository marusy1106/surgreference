import 'dart:convert';
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
