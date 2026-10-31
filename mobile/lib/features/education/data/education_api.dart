import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import 'education_models.dart';

/// Учебный профиль и справочники вузов и специальностей. Все ошибки приходят как [ApiException].
class EducationApi {
  EducationApi(this._client);

  final ApiClient _client;

  Dio get _dio => _client.dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<EducationProfile> profile() => _call(() async {
    final r = await _dio.get<Map<String, dynamic>>('me/education');
    return EducationProfile.fromJson(r.data!);
  });

  Future<EducationProfile> save({
    required EducationStatus status,
    UniversityOption? university,
    int? facultyId,
    SpecialtyOption? specialty,
    int? course,
    int? studyYear,
    int? graduationYear,
  }) => _call(() async {
    final r = await _dio.put<Map<String, dynamic>>(
      'me/education',
      data: {
        'status': status.api,
        'university_id': university?.id,
        'faculty_id': facultyId,
        'specialty_id': specialty?.id,
        'course': course,
        'study_year': studyYear,
        'graduation_year': graduationYear,
      },
    );
    return EducationProfile.fromJson(r.data!);
  });

  Future<void> delete() => _call(() => _dio.delete<void>('me/education'));

  Future<List<UniversityOption>> universities(String search) => _call(() async {
    final r = await _dio.get<List<dynamic>>('universities', queryParameters: {'search': search});
    return [for (final u in r.data!) UniversityOption.fromJson(u as Map<String, dynamic>)];
  });

  Future<List<SpecialtyOption>> specialties(String level) => _call(() async {
    final r = await _dio.get<List<dynamic>>('specialties', queryParameters: {'level': level});
    return [for (final s in r.data!) SpecialtyOption.fromJson(s as Map<String, dynamic>)];
  });

  /// «Моего вуза нет» — заявка на модерацию.
  Future<void> requestUniversity(String name, String city) =>
      _call(() => _dio.post<void>('universities/requests', data: {'name': name, 'city': city}));
}
