import 'package:dio/dio.dart';

/// Ошибка API в формате бэкенда `{"error": {"code", "message", "fields"}}` или сетевая.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.fields = const {},
    this.retryAfter,
  });

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) {
      return const ApiException(code: 'unknown', message: 'Что-то пошло не так. Попробуйте ещё раз.');
    }
    final response = error.response;
    if (response == null) {
      return const ApiException(code: 'network', message: 'Нет связи с сервером. Проверьте интернет.');
    }
    final body = response.data;
    final payload = body is Map && body['error'] is Map ? body['error'] as Map : const {};
    final rawFields = payload['fields'];
    final fields = <String, List<String>>{
      if (rawFields is Map)
        for (final MapEntry(:key, :value) in rawFields.entries)
          '$key': value is List ? [for (final v in value) _fieldMessage(v)] : [_fieldMessage(value)],
    };
    final seconds = int.tryParse(response.headers.value('retry-after') ?? '');
    return ApiException(
      code: payload['code'] as String? ?? 'http_${response.statusCode}',
      message: payload['message'] as String? ?? 'Ошибка сервера (${response.statusCode}). Попробуйте позже.',
      statusCode: response.statusCode,
      fields: fields,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  final String code;
  final String message;
  final int? statusCode;

  /// Ошибки по полям формы; вложенные (consents[0].version) сведены к строке.
  final Map<String, List<String>> fields;
  final Duration? retryAfter;

  bool get isNetwork => code == 'network';
  bool get isThrottled => statusCode == 429;

  String? field(String name) => fields[name]?.join(' ');

  /// Текст для пользователя: у лимита — через сколько повторить, у формы — первая ошибка поля без привязки.
  String get userMessage {
    if (isThrottled) {
      final wait = retryAfter;
      if (wait == null) return 'Слишком много попыток. Попробуйте позже.';
      final minutes = (wait.inSeconds / 60).ceil();
      return minutes <= 1
          ? 'Слишком много попыток. Повторите через ${wait.inSeconds} с.'
          : 'Слишком много попыток. Повторите через $minutes мин.';
    }
    return fields['non_field_errors']?.first ?? fields['code']?.first ?? message;
  }

  static String _fieldMessage(Object? value) => switch (value) {
    final Map<dynamic, dynamic> nested => nested.values.map(_fieldMessage).join(' '),
    final List<dynamic> list => list.map(_fieldMessage).join(' '),
    _ => '$value',
  };

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
