import 'dart:async';

import 'package:dio/dio.dart';

import 'token_store.dart';

/// HTTP-клиент API с авторизацией: подставляет access-токен, при 401 один раз обновляет пару токенов
/// (параллельные запросы ждут то же обновление) и повторяет запрос. Если refresh отвергнут —
/// чистит токены и вызывает [onSessionExpired]. Сетевая ошибка при обновлении сессию не завершает.
class ApiClient {
  ApiClient({required String baseUrl, required this.store, HttpClientAdapter? adapter})
    : dio = Dio(_options(baseUrl)),
      _refreshDio = Dio(_options(baseUrl)) {
    if (adapter != null) {
      dio.httpClientAdapter = adapter;
      _refreshDio.httpClientAdapter = adapter;
    }
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  );

  /// Флаг в `Options.extra`: запрос без токена (вход, регистрация, коды).
  static const public = {'public': true};

  final Dio dio;
  final Dio _refreshDio;
  final TokenStore store;

  /// Сессия завершена сервером (refresh отозван, повторно использован или истёк).
  void Function()? onSessionExpired;

  /// Новая пара токенов получена при обновлении: сюда же приходит актуальный пользователь.
  void Function(Map<String, dynamic> tokenPair)? onTokensRefreshed;

  String? _access;
  Future<bool>? _refreshing;

  bool get hasAccessToken => _access != null;

  Future<void> saveTokens(Map<String, dynamic> pair) async {
    _access = pair['access'] as String;
    await store.writeRefresh(pair['refresh'] as String);
  }

  Future<void> clearTokens() async {
    _access = null;
    await store.clear();
  }

  /// Обновить пару токенов; false — refresh-токена нет или сервер его отверг.
  Future<bool> refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final token = await store.readRefresh();
    if (token == null) return false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>('auth/refresh', data: {'refresh': token});
      await saveTokens(response.data!);
      onTokensRefreshed?.call(response.data!);
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        await clearTokens();
        return false;
      }
      rethrow;
    }
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['public'] != true && _access != null) {
      options.headers['Authorization'] = 'Bearer $_access';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final options = error.requestOptions;
    final retriable =
        error.response?.statusCode == 401 && options.extra['public'] != true && options.extra['retried'] != true;
    if (!retriable) return handler.next(error);
    try {
      if (!await refresh()) {
        onSessionExpired?.call();
        return handler.next(error);
      }
      options.extra['retried'] = true;
      options.headers['Authorization'] = 'Bearer $_access';
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
