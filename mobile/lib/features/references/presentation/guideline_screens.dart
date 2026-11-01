import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/references_models.dart';
import 'reference_parts.dart';

/// Реестр клинических рекомендаций: поиск по названию или коду МКБ-10, фильтр по статусу.
class GuidelinesScreen extends StatelessWidget {
  const GuidelinesScreen({
    super.key,
    required this.results,
    this.query = '',
    this.status,
    this.onSearch,
    this.onStatus,
    this.onOpen,
    this.onBack,
    this.onRetry,
  });

  final AsyncValue<List<GuidelineBrief>> results;
  final String query;
  final GuidelineStatus? status;
  final ValueChanged<String>? onSearch;
  final ValueChanged<GuidelineStatus?>? onStatus;
  final ValueChanged<GuidelineBrief>? onOpen;
  final VoidCallback? onBack;
  final VoidCallback? onRetry;

  static const _filters = <GuidelineStatus?, String>{
    null: 'Все',
    GuidelineStatus.active: 'Действуют',
    GuidelineStatus.underRevision: 'На пересмотре',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: referenceAppBar(context, 'Справочники', onBack),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SrSpace.xl, SrSpace.s, SrSpace.xl, SrSpace.xxl),
        children: [
          Text('Клинические рекомендации', style: theme.headlineMedium),
          const SizedBox(height: SrSpace.l),
          ReferenceSearchField(hint: 'Название или код МКБ-10', initial: query, onChanged: onSearch),
          const SizedBox(height: SrSpace.l),
          Wrap(
            spacing: SrSpace.s,
            runSpacing: SrSpace.s,
            children: [
              for (final MapEntry(key: s, value: label) in _filters.entries)
                ChipFilter(label: label, selected: s == status, onSelected: (_) => onStatus?.call(s)),
            ],
          ),
          const SizedBox(height: SrSpace.l),
          ...asyncRows(
            context,
            results,
            emptyTitle: 'Ничего не нашлось',
            emptyMessage: 'Попробуйте другое название, код МКБ-10 или сбросьте фильтр.',
            onRetry: onRetry,
            row: (g) => GuidelineRow(g, onTap: onOpen == null ? null : () => onOpen!(g)),
          ),
        ],
      ),
    );
  }
}

class GuidelineScreen extends StatelessWidget {
  const GuidelineScreen({
    super.key,
    required this.detail,
    this.onOpenCode,
    this.onOpenLesson,
    this.onOpenSource,
    this.onBack,
  });

  final GuidelineDetail detail;
  final ValueChanged<String>? onOpenCode;
  final ValueChanged<CitingLesson>? onOpenLesson;
  final VoidCallback? onOpenSource;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final g = detail.brief;
    final muted = theme.bodyMedium!.copyWith(color: c.textMuted);
    return Scaffold(
      appBar: referenceAppBar(context, 'Клинические рекомендации', onBack),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SrSpace.xl, SrSpace.s, SrSpace.xl, SrSpace.xxl),
        children: [
          Align(alignment: Alignment.centerLeft, child: GuidelineStatusBadge(g.status)),
          const SizedBox(height: SrSpace.m),
          Text(g.title, style: theme.headlineMedium),
          if (detail.developer.isNotEmpty) ...[const SizedBox(height: SrSpace.s), Text(detail.developer, style: muted)],
          if (g.status == GuidelineStatus.underRevision) ...[
            const SizedBox(height: SrSpace.l),
            _Notice('КР пересматривается: положения могут измениться. Сверяйтесь с актуальным текстом документа.'),
          ],
          const SizedBox(height: SrSpace.l),
          Tile(
            child: Row(
              children: [
                for (final (label, value) in [
                  ('Версия', g.version.isEmpty ? '—' : g.version),
                  ('Утверждена', formatDate(g.approvedAt)),
                  ('Пересмотр', formatDate(g.revisionDue)),
                ])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TileLabel(label),
                        const SizedBox(height: SrSpace.xs),
                        Text(value, style: theme.titleMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (detail.icd.isNotEmpty) ...[
            const SizedBox(height: SrSpace.xl),
            SectionHeader('Коды МКБ-10'),
            const SizedBox(height: SrSpace.s),
            for (final code in detail.icd)
              ReferenceRow(
                leading: IcdCodeLabel(code.code),
                title: code.title,
                onTap: onOpenCode == null ? null : () => onOpenCode!(code.code),
              ),
          ],
          if (detail.summary.isNotEmpty) ...[
            const SizedBox(height: SrSpace.xl),
            SectionHeader('Ключевые положения'),
            const SizedBox(height: SrSpace.s),
            for (final item in detail.summary)
              Padding(
                padding: const EdgeInsets.only(bottom: SrSpace.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: theme.bodyLarge!.copyWith(color: c.marker)),
                    Expanded(child: Text(item, style: theme.bodyLarge)),
                  ],
                ),
              ),
          ],
          if (detail.lessons.isNotEmpty) ...[
            const SizedBox(height: SrSpace.xl),
            SectionHeader('Уроки по этой КР'),
            const SizedBox(height: SrSpace.s),
            for (final lesson in detail.lessons)
              ReferenceRow(
                leading: Container(
                  width: kMinTapTarget,
                  height: kMinTapTarget,
                  decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                  child: Icon(Icons.menu_book_outlined, color: c.text),
                ),
                title: lesson.title,
                onTap: onOpenLesson == null ? null : () => onOpenLesson!(lesson),
              ),
          ],
          if (detail.versions.length > 1) ...[
            const SizedBox(height: SrSpace.xl),
            SectionHeader('История версий'),
            const SizedBox(height: SrSpace.s),
            for (final v in detail.versions)
              Padding(
                padding: const EdgeInsets.only(bottom: SrSpace.xs),
                child: Text(
                  '${v.version} — утверждена ${formatDate(v.approvedAt)}${v.current ? ' · текущая' : ''}',
                  style: v.current ? theme.bodyMedium : muted,
                ),
              ),
          ],
          if (detail.sourceUrl.isNotEmpty) ...[
            const SizedBox(height: SrSpace.xl),
            PillButton(label: 'Полный текст в рубрикаторе КР', onPressed: onOpenSource),
          ],
          const SizedBox(height: SrSpace.l),
          const Disclaimer(),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Container(
      padding: const EdgeInsets.all(SrSpace.l),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.warning.withValues(alpha: 0.12), c.surface),
        borderRadius: BorderRadius.circular(SrRadius.tile),
        border: Border(left: BorderSide(color: c.warning, width: 4)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
