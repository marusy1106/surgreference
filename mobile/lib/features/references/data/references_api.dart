import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import 'references_models.dart';

/// Справочники МКБ-10 и клинических рекомендаций. Все ошибки приходят как [ApiException].
class ReferencesApi {
  ReferencesApi(this._client);

  final ApiClient _client;

  Dio get _dio => _client.dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Без запроса — классы МКБ-10.
  Future<List<IcdCode>> searchIcd(String search) => _call(() async {
    final r = await _dio.get<List<dynamic>>('icd10', queryParameters: {'search': search});
    return [for (final c in r.data!) IcdCode.fromJson(c as Map<String, dynamic>)];
  });

  Future<IcdCodeDetail> icdCode(String code) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('icd10/${Uri.encodeComponent(code)}');
    return IcdCodeDetail.fromJson(r.data!);
  });

  Future<List<GuidelineBrief>> searchGuidelines(String search, GuidelineStatus? status) => _call(() async {
    final r = await _dio.get<List<dynamic>>('guidelines', queryParameters: {'search': search, 'status': ?status?.api});
    return [for (final g in r.data!) GuidelineBrief.fromJson(g as Map<String, dynamic>)];
  });

  Future<GuidelineDetail> guideline(int id) => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('guidelines/$id');
    return GuidelineDetail.fromJson(r.data!);
  });
}
