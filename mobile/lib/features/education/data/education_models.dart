/// Образовательный статус. Уровень специальности в справочнике зависит от статуса; у врача — ординатурские.
enum EducationStatus {
  student('student', 'Студент', 'specialitet'),
  resident('resident', 'Ординатор', 'residency'),
  postgraduate('postgraduate', 'Аспирант', 'postgraduate'),
  doctor('doctor', 'Врач', 'residency');

  const EducationStatus(this.api, this.label, this.specialtyLevel);

  final String api;
  final String label;
  final String specialtyLevel;

  static EducationStatus? fromApi(String? value) => values.where((s) => s.api == value).firstOrNull;

  bool get hasCourse => this == student;
  bool get hasStudyYear => this == resident || this == postgraduate;
}

class UniversityOption {
  const UniversityOption({required this.id, required this.name, required this.shortName, required this.city});

  factory UniversityOption.fromJson(Map<String, dynamic> j) => UniversityOption(
    id: j['id'] as int,
    name: j['name'] as String,
    shortName: j['short_name'] as String? ?? '',
    city: j['city'] as String? ?? '',
  );

  final int id;
  final String name;
  final String shortName;
  final String city;

  String get title => shortName.isEmpty ? name : shortName;
}

class SpecialtyOption {
  const SpecialtyOption({required this.id, required this.code, required this.name});

  factory SpecialtyOption.fromJson(Map<String, dynamic> j) =>
      SpecialtyOption(id: j['id'] as int, code: j['code'] as String, name: j['name'] as String);

  final int id;
  final String code;
  final String name;
}

class EducationProfile {
  const EducationProfile({
    this.status,
    this.university,
    this.facultyId,
    this.specialty,
    this.course,
    this.studyYear,
    this.graduationYear,
    this.requestedUniversity,
  });

  factory EducationProfile.fromJson(Map<String, dynamic> j) {
    final university = j['university'] as Map<String, dynamic>?;
    final specialty = j['specialty'] as Map<String, dynamic>?;
    final request = j['university_request'] as Map<String, dynamic>?;
    return EducationProfile(
      status: EducationStatus.fromApi(j['status'] as String?),
      university: university == null ? null : UniversityOption.fromJson(university),
      facultyId: (j['faculty'] as Map<String, dynamic>?)?['id'] as int?,
      specialty: specialty == null ? null : SpecialtyOption.fromJson(specialty),
      course: j['course'] as int?,
      studyYear: j['study_year'] as int?,
      graduationYear: j['graduation_year'] as int?,
      requestedUniversity: request?['name'] as String?,
    );
  }

  /// null — профиль не заполнен.
  final EducationStatus? status;
  final UniversityOption? university;
  final int? facultyId;
  final SpecialtyOption? specialty;
  final int? course;
  final int? studyYear;
  final int? graduationYear;

  /// Название из заявки «Моего вуза нет», пока её не рассмотрели.
  final String? requestedUniversity;

  /// «Студент, 5 курс», «Ординатор, 1 год», «Врач».
  String get statusLine => switch (status) {
    null => 'Не указан',
    final s when s.hasCourse && course != null => '${s.label}, $course курс',
    final s when s.hasStudyYear && studyYear != null => '${s.label}, $studyYear год',
    final s => s.label,
  };

  /// «Сеченовский университет · Лечебное дело».
  String get universityLine {
    final place = university?.title ?? (requestedUniversity == null ? null : '$requestedUniversity (на проверке)');
    final parts = [?place, ?specialty?.name];
    if (parts.isNotEmpty) return parts.join(' · ');
    return status == null ? 'Укажите вуз — откроется рейтинг «Мой вуз»' : 'Вуз не указан';
  }
}
