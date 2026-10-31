import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../../learning/learning_providers.dart';
import '../data/education_models.dart';
import '../education_providers.dart';
import 'university_search_page.dart';

/// Учебный профиль: статус, вуз, специальность, курс или год обучения. Уровень знаний от него не зависит.
class EducationPage extends ConsumerWidget {
  const EducationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(educationProvider),
    onRetry: () => ref.invalidate(educationProvider),
    data: (profile) => _EducationForm(profile),
  );
}

class _EducationForm extends ConsumerStatefulWidget {
  const _EducationForm(this.initial);

  final EducationProfile initial;

  @override
  ConsumerState<_EducationForm> createState() => _EducationFormState();
}

class _EducationFormState extends ConsumerState<_EducationForm> {
  late EducationStatus? _status = widget.initial.status;
  late UniversityOption? _university = widget.initial.university;
  late SpecialtyOption? _specialty = widget.initial.specialty;
  late int? _course = widget.initial.course;
  late int? _studyYear = widget.initial.studyYear;
  late String? _requested = widget.initial.requestedUniversity;
  ApiException? _error;
  var _busy = false;

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _setStatus(EducationStatus status) => setState(() {
    // Специальность другого уровня (специалитет у ординатора) больше не подходит.
    if (_status?.specialtyLevel != status.specialtyLevel) _specialty = null;
    _status = status;
  });

  Future<void> _pickUniversity() async {
    final pick = await context.push<UniversityPick>(Routes.universitySearch);
    if (pick == null || !mounted) return;
    setState(() {
      _university = pick.university ?? _university;
      _requested = pick.requested ?? _requested;
    });
    if (pick.requested != null) {
      _message('Заявка отправлена. Когда вуз добавят в справочник, он появится в профиле сам.');
    }
  }

  Future<void> _pickSpecialty() async {
    final status = _status!;
    final picked = await showModalBottomSheet<SpecialtyOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SpecialtySheet(level: status.specialtyLevel, selected: _specialty?.id),
    );
    if (picked != null) setState(() => _specialty = picked);
  }

  Future<void> _save() async {
    final status = _status;
    if (status == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(educationApiProvider)
          .save(
            status: status,
            university: _university,
            // Факультет относится к вузу — при смене вуза сбрасывается.
            facultyId: _university?.id == widget.initial.university?.id ? widget.initial.facultyId : null,
            specialty: _specialty,
            course: status.hasCourse ? _course : null,
            studyYear: status.hasStudyYear ? _studyYear : null,
            graduationYear: widget.initial.graduationYear,
          );
      _done('Учебный профиль сохранён');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить учебный профиль?'),
        content: const Text('Статус, вуз и курс сотрутся. Вы пропадёте из рейтинга «Мой вуз», XP останутся.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(educationApiProvider).delete();
      _done('Учебный профиль удалён');
    } on ApiException catch (e) {
      _message(e.userMessage);
    }
  }

  void _done(String text) {
    ref
      ..invalidate(educationProvider)
      ..invalidate(profileProvider)
      ..invalidate(leaderboardProvider);
    if (!mounted) return;
    _message(text);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final status = _status;
    final error = _error;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            FormHeader(
              title: 'Учебный профиль',
              subtitle:
                  'Нужен для рейтинга «Мой вуз». Другие участники рейтинга видят вуз, '
                  'если вы участвуете в рейтинге. На уровень и XP профиль не влияет.',
              onBack: context.pop,
            ),
            const SectionHeader('Статус'),
            const SizedBox(height: SrSpace.s),
            _Chips(values: EducationStatus.values, label: (s) => s.label, selected: status, onSelected: _setStatus),
            if (status != null) ...[
              const SizedBox(height: SrSpace.xl),
              const SectionHeader('Вуз'),
              const SizedBox(height: SrSpace.s),
              _PickerTile(
                title: _university?.title ?? _requested ?? 'Выбрать вуз',
                subtitle: _university != null
                    ? _university!.city
                    : _requested != null
                    ? 'Заявка на проверке'
                    : 'Поиск по названию, сокращению или городу',
                onTap: _pickUniversity,
              ),
              const SizedBox(height: SrSpace.xl),
              const SectionHeader('Специальность'),
              const SizedBox(height: SrSpace.s),
              _PickerTile(
                title: _specialty?.name ?? 'Выбрать специальность',
                subtitle: _specialty?.code ?? 'Необязательно',
                onTap: _pickSpecialty,
              ),
              if (error?.field('specialty_id') case final message?) ...[
                const SizedBox(height: SrSpace.s),
                FormMessage(message),
              ],
              if (status.hasCourse || status.hasStudyYear) ...[
                const SizedBox(height: SrSpace.xl),
                SectionHeader(status.hasCourse ? 'Курс' : 'Год обучения'),
                const SizedBox(height: SrSpace.s),
                _Chips(
                  values: [for (var i = 1; i <= (status.hasCourse ? 6 : 5); i++) i],
                  label: (n) => status.hasCourse ? '$n курс' : '$n год',
                  selected: status.hasCourse ? _course : _studyYear,
                  onSelected: (n) => setState(() => status.hasCourse ? _course = n : _studyYear = n),
                ),
              ],
            ],
            if (error != null && error.field('specialty_id') == null) ...[
              const SizedBox(height: SrSpace.m),
              FormMessage(error.isThrottled ? 'Профиль можно менять до 10 раз в сутки.' : error.userMessage),
            ],
            const SizedBox(height: SrSpace.xl),
            PillButton(label: _busy ? 'Сохраняем…' : 'Сохранить', onPressed: _busy || status == null ? null : _save),
            if (widget.initial.status != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: c.textMuted, minimumSize: const Size(0, kMinTapTarget)),
                  child: const Text('Удалить учебный профиль'),
                ),
              ),
            const SizedBox(height: SrSpace.s),
            Text('Подтверждение принадлежности к вузу появится позже — по вузовской почте.', style: theme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Chips<T> extends StatelessWidget {
  const _Chips({required this.values, required this.label, required this.selected, required this.onSelected});

  final List<T> values;
  final String Function(T) label;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: SrSpace.s,
    runSpacing: SrSpace.s,
    children: [
      for (final v in values) ChipFilter(label: label(v), selected: v == selected, onSelected: (_) => onSelected(v)),
    ],
  );
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Tile(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.titleMedium),
                Text(subtitle, style: theme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}

class _SpecialtySheet extends ConsumerWidget {
  const _SpecialtySheet({required this.level, required this.selected});

  final String level;
  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => AsyncView(
        value: ref.watch(specialtiesProvider(level)),
        onRetry: () => ref.invalidate(specialtiesProvider(level)),
        data: (items) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(SrSpace.xl, 0, SrSpace.xl, SrSpace.xl),
          children: [
            Text('Специальность', style: theme.titleLarge),
            const SizedBox(height: SrSpace.m),
            for (final s in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: kMinTapTarget,
                title: Text(s.name),
                subtitle: Text(s.code),
                trailing: s.id == selected ? Icon(Icons.check_rounded, color: c.accent) : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
  }
}
