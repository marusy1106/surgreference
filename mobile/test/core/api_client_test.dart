import 'package:flutter_test/flutter_test.dart';
import 'package:surgreference/core/api/api_client.dart';
import 'package:surgreference/core/api/api_error.dart';
import 'package:surgreference/core/api/token_store.dart';
import 'package:surgreference/features/auth/data/auth_api.dart';
import 'package:surgreference/features/auth/data/models.dart';

import '../fake_backend.dart';

void main() {
  late MemoryTokenStore store;
  late ApiClient client;
  late AuthApi api;
  late int refreshCalls;
  late int expired;

  FakeBackend backend({FakeResponse Function()? onRefresh}) => FakeBackend({
    'GET me': (r, _) => r.headers['Authorization'] == 'Bearer fresh' ? FakeResponse(200, userJson()) : unauthorized,
    'POST auth/refresh': (r, body) {
      refreshCalls++;
      if (onRefresh != null) return onRefresh();
      return body!['refresh'] == 'r1' ? FakeResponse(200, tokenPair('fresh', 'r2')) : unauthorized;
    },
  });

  void setUpClient(FakeBackend fake) {
    store = MemoryTokenStore();
    client = ApiClient(baseUrl: 'http://test/api/v1/', store: store, adapter: fake);
    client.onSessionExpired = () => expired++;
    api = AuthApi(client, const DeviceInfo(platform: 'ios', appVersion: 'test'));
  }

  setUp(() {
    refreshCalls = 0;
    expired = 0;
  });

  test('expired access is refreshed once and the request is retried', () async {
    setUpClient(backend());
    await client.saveTokens({'access': 'stale', 'refresh': 'r1'});

    final users = await Future.wait([api.me(), api.me(), api.me()]);

    expect(users.map((u) => u.displayName), everyElement('scalpel_anna'));
    expect(refreshCalls, 1, reason: 'parallel 401s must share one refresh');
    expect(await store.readRefresh(), 'r2');
    expect(expired, 0);
  });

  test('rejected refresh clears tokens and reports the expired session', () async {
    setUpClient(backend());
    await client.saveTokens({'access': 'stale', 'refresh': 'reused'});

    await expectLater(api.me(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));

    expect(await store.readRefresh(), isNull);
    expect(client.hasAccessToken, isFalse);
    expect(expired, 1);
  });

  test('network failure during refresh keeps the refresh token', () async {
    setUpClient(backend(onRefresh: () => throw StateError('offline')));
    await client.saveTokens({'access': 'stale', 'refresh': 'r1'});

    await expectLater(api.me(), throwsA(isA<ApiException>()));

    expect(await store.readRefresh(), 'r1', reason: 'no logout just because the network is down');
    expect(expired, 0);
  });

  test('public endpoints are sent without a token and never trigger a refresh', () async {
    final fake = FakeBackend({'POST auth/login': (_, _) => unauthorized});
    setUpClient(fake);
    await client.saveTokens({'access': 'stale', 'refresh': 'r1'});

    await expectLater(api.login('anna@example.org', 'wrong'), throwsA(isA<ApiException>()));

    expect(fake.log.single, 'POST auth/login -');
    expect(refreshCalls, 0);
  });

  test('restore without a stored refresh token makes no requests', () async {
    final fake = backend();
    setUpClient(fake);

    expect(await api.restore(), isNull);
    expect(fake.log, isEmpty);
  });

  group('ApiException', () {
    test('maps validation errors to fields, nested ones to one line', () async {
      setUpClient(
        FakeBackend({
          'POST auth/register': (_, _) => const FakeResponse(400, {
            'error': {
              'code': 'validation_error',
              'message': 'Проверьте введённые данные',
              'fields': {
                'display_name': ['Этот никнейм уже занят'],
                'consents': [
                  {
                    'version': ['Неверная версия'],
                  },
                ],
              },
            },
          }),
        }),
      );

      final error = await api
          .register(email: 'a@example.org', password: 'p', displayName: 'n', consents: const {})
          .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

      expect(error!.field('display_name'), 'Этот никнейм уже занят');
      expect(error.field('consents'), 'Неверная версия');
    });

    test('throttled error tells when to retry', () {
      const e = ApiException(code: 'throttled', message: '', statusCode: 429, retryAfter: Duration(seconds: 900));
      expect(e.userMessage, 'Слишком много попыток. Повторите через 15 мин.');
    });
  });
}
