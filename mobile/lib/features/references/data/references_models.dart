/// Справочники МКБ-10 и клинических рекомендаций (docs/05-learning.md).
class IcdCode {
  const IcdCode({required this.code, required this.title, this.isLeaf = true});

  final String code;
  final String title;
  final bool isLeaf;

  /// «K35-K38» — диапазон (класс или блок), а не код диагноза.
  bool get isRange => code.contains('-');

  factory IcdCode.fromJson(Map<String, dynamic> j) =>
      IcdCode(code: j['code'] as String, title: j['title'] as String, isLeaf: j['is_leaf'] as bool? ?? true);
}

class IcdCodeDetail {
  const IcdCodeDetail({required this.code, required this.ancestors, required this.children, required this.guidelines});

  final IcdCode code;
  final List<IcdCode> ancestors;
  final List<IcdCode> children;
  final List<GuidelineBrief> guidelines;

  factory IcdCodeDetail.fromJson(Map<String, dynamic> j) => IcdCodeDetail(
    code: IcdCode.fromJson(j),
    ancestors: [for (final a in j['ancestors'] as List) IcdCode.fromJson(a as Map<String, dynamic>)],
    children: [for (final c in j['children'] as List) IcdCode.fromJson(c as Map<String, dynamic>)],
    guidelines: [for (final g in j['guidelines'] as List) GuidelineBrief.fromJson(g as Map<String, dynamic>)],
  );
}

enum GuidelineStatus {
  active('active', 'Действует'),
  underRevision('under_revision', 'На пересмотре'),
  superseded('superseded', 'Заменена'),
  withdrawn('withdrawn', 'Отменена');

  const GuidelineStatus(this.api, this.label);

  final String api;
  final String label;

  static GuidelineStatus parse(String? value) =>
      values.firstWhere((s) => s.api == value, orElse: () => GuidelineStatus.active);
}

class GuidelineBrief {
  const GuidelineBrief({
    required this.id,
    required this.title,
    required this.status,
    this.icdCodes = const [],
    this.version = '',
    this.approvedAt,
    this.revisionDue,
  });

  final int id;
  final String title;
  final GuidelineStatus status;
  final List<String> icdCodes;
  final String version;
  final DateTime? approvedAt;
  final DateTime? revisionDue;

  factory GuidelineBrief.fromJson(Map<String, dynamic> j) => GuidelineBrief(
    id: j['id'] as int,
    title: j['title'] as String,
    status: GuidelineStatus.parse(j['status'] as String?),
    icdCodes: [for (final c in j['icd_codes'] as List? ?? const []) '$c'],
    version: j['version'] as String? ?? '',
    approvedAt: DateTime.tryParse(j['approved_at'] as String? ?? ''),
    revisionDue: DateTime.tryParse(j['revision_due'] as String? ?? ''),
  );
}

class GuidelineVersionRow {
  const GuidelineVersionRow({required this.version, required this.approvedAt, required this.current});

  final String version;
  final DateTime? approvedAt;
  final bool current;
}

class CitingLesson {
  const CitingLesson({required this.id, required this.title});

  final int id;
  final String title;
}

class GuidelineDetail {
  const GuidelineDetail({
    required this.brief,
    this.developer = '',
    this.summary = const [],
    this.sourceUrl = '',
    this.icd = const [],
    this.versions = const [],
    this.lessons = const [],
  });

  final GuidelineBrief brief;
  final String developer;
  final List<String> summary;
  final String sourceUrl;
  final List<IcdCode> icd;
  final List<GuidelineVersionRow> versions;
  final List<CitingLesson> lessons;

  factory GuidelineDetail.fromJson(Map<String, dynamic> j) => GuidelineDetail(
    brief: GuidelineBrief.fromJson(j),
    developer: j['developer'] as String? ?? '',
    summary: [for (final s in j['summary'] as List? ?? const []) '$s'],
    sourceUrl: j['source_url'] as String? ?? '',
    icd: [for (final c in j['icd'] as List? ?? const []) IcdCode.fromJson(c as Map<String, dynamic>)],
    versions: [
      for (final v in j['versions'] as List? ?? const [])
        GuidelineVersionRow(
          version: (v as Map<String, dynamic>)['version'] as String,
          approvedAt: DateTime.tryParse(v['approved_at'] as String? ?? ''),
          current: v['current'] as bool? ?? false,
        ),
    ],
    lessons: [
      for (final l in j['lessons'] as List? ?? const [])
        CitingLesson(id: (l as Map<String, dynamic>)['id'] as int, title: l['title'] as String),
    ],
  );
}

/// 01.03.2024 — даты документов.
String formatDate(DateTime? date) =>
    date == null ? '—' : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
