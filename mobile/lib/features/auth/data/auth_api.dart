import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import 'models.dart';

/// Эндпоинты авторизации и аккаунта. Все ошибки приходят как [ApiException].
class AuthApi {
  AuthApi(this._client, this._device);

  final ApiClient _client;
  final DeviceInfo _device;

  Dio get _dio => _client.dio;
  static final _public = Options(extra: ApiClient.public);

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<Map<String, String>> legalVersions() => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('app/config', options: _public);
    return (r.data!['legal_documents'] as Map).map((k, v) => MapEntry('$k', '$v'));
  });

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required Map<String, String> consents,
  }) => _call(
    () => _dio.post<void>(
      'auth/register',
      options: _public,
      data: {
        'email': email,
        'password': password,
        'display_name': displayName,
        'consents': [
          for (final MapEntry(key: document, value: version) in consents.entries)
            {'document': document, 'version': version},
        ],
      },
    ),
  );

  Future<User> verifyEmail(String email, String code) => _session(
    () => _dio.post(
      'auth/verify-email',
      options: _public,
      data: {'email': email, 'code': code, 'device': _device.toJson()},
    ),
  );

  Future<void> resendCode(String email) =>
      _call(() => _dio.post<void>('auth/resend-code', options: _public, data: {'email': email}));

  Future<User> login(String email, String password) => _session(
    () => _dio.post(
      'auth/login',
      options: _public,
      data: {'email': email, 'password': password, 'device': _device.toJson()},
    ),
  );

  /// Восстановить сессию по сохранённому refresh-токену; null — входа нет.
  Future<User?> restore() => _call(() async {
    if (!await _client.refresh()) return null;
    return me();
  });

  Future<void> logout() async {
    try {
      await _dio.post<void>('auth/logout');
    } on DioException {
      // Выходим локально и без сети: сессия на сервере истечёт сама или отзывается с другого устройства.
    }
    await _client.clearTokens();
  }

  Future<void> forgotPassword(String email) =>
      _call(() => _dio.post<void>('auth/password/forgot', options: _public, data: {'email': email}));

  Future<void> resetPassword(String email, String code, String newPassword) => _call(
    () => _dio.post<void>(
      'auth/password/reset',
      options: _public,
      data: {'email': email, 'code': code, 'new_password': newPassword},
    ),
  );

  Future<void> changePassword(String oldPassword, String newPassword) => _call(
    () => _dio.post<void>('auth/password/change', data: {'old_password': oldPassword, 'new_password': newPassword}),
  );

  Future<User> me() => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('me');
    return User.fromJson(r.data!);
  });

  Future<User> updateMe({String? displayName, String? firstName}) => _call(() async {
    final r = await _dio.patch<Map<String, dynamic>>(
      'me',
      data: {'display_name': ?displayName, 'first_name': ?firstName},
    );
    return User.fromJson(r.data!);
  });

  Future<List<DeviceSession>> sessions() => _call(() async {
    final r = await _dio.get<List<dynamic>>('auth/sessions');
    return [for (final s in r.data!) DeviceSession.fromJson(s as Map<String, dynamic>)];
  });

  Future<void> revokeSession(String id) => _call(() => _dio.delete<void>('auth/sessions/$id'));

  Future<void> revokeOtherSessions() => _call(() => _dio.delete<void>('auth/sessions'));

  Future<void> requestDeletionCode() => _call(() => _dio.post<void>('me/deletion-code'));

  Future<void> deleteAccount(String code) => _call(() async {
    await _dio.post<void>('me/delete', data: {'code': code});
    await _client.clearTokens();
  });

  Future<void> requestExport() => _call(() => _dio.post<void>('me/export'));

  Future<User> _session(Future<Response<dynamic>> Function() request) => _call(() async {
    final r = await request();
    final pair = r.data as Map<String, dynamic>;
    await _client.saveTokens(pair);
    return User.fromJson(pair['user'] as Map<String, dynamic>);
  });
}
