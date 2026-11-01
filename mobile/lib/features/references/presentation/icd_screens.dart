import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/references_models.dart';
import 'reference_parts.dart';

/// Поиск по МКБ-10: код («K35», «к35.8») или слова из названия. Без запроса — классы.
class IcdSearchScreen extends StatelessWidget {
  const IcdSearchScreen({
    super.key,
    required this.results,
    this.query = '',
    this.onSearch,
    this.onOpen,
    this.onBack,
    this.onRetry,
  });

  final AsyncValue<List<IcdCode>> results;
  final String query;
  final ValueChanged<String>? onSearch;
  final ValueChanged<IcdCode>? onOpen;
  final VoidCallback? onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: referenceAppBar(context, 'Справочники', onBack),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SrSpace.xl, SrSpace.s, SrSpace.xl, SrSpace.xxl),
        children: [
          Text('МКБ-10', style: theme.headlineMedium),
          const SizedBox(height: SrSpace.l),
          ReferenceSearchField(hint: 'Код или название диагноза', initial: query, onChanged: onSearch),
          const SizedBox(height: SrSpace.l),
          if (query.trim().isEmpty) ...[SectionHeader('Классы'), const SizedBox(height: SrSpace.s)],
          ...asyncRows(
            context,
            results,
            emptyTitle: 'Ничего не нашлось',
            emptyMessage: 'Проверьте код или попробуйте другое слово из названия.',
            onRetry: onRetry,
            row: (code) => ReferenceRow(
              leading: IcdCodeLabel(code.code),
              title: code.title,
              onTap: onOpen == null ? null : () => onOpen!(code),
            ),
          ),
        ],
      ),
    );
  }
}

class IcdCodeScreen extends StatelessWidget {
  const IcdCodeScreen({super.key, required this.detail, this.onOpenCode, this.onOpenGuideline, this.onBack});

  final IcdCodeDetail detail;
  final ValueChanged<String>? onOpenCode;
  final ValueChanged<GuidelineBrief>? onOpenGuideline;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final code = detail.code;
    return Scaffold(
      appBar: referenceAppBar(context, 'МКБ-10', onBack),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SrSpace.xl, SrSpace.s, SrSpace.xl, SrSpace.xxl),
        children: [
          if (detail.ancestors.isNotEmpty) ...[
            Wrap(
              spacing: SrSpace.xs,
              runSpacing: SrSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, a) in detail.ancestors.indexed) ...[
                  if (i > 0) Icon(Icons.chevron_right_rounded, size: 16, color: c.textMuted),
                  Semantics(
                    button: true,
                    label: '${a.code} ${a.title}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(SrRadius.pill),
                      onTap: onOpenCode == null ? null : () => onOpenCode!(a.code),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: SrSpace.xs),
                        child: Text(a.code, style: theme.labelMedium!.copyWith(color: c.textMuted)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: SrSpace.m),
          ],
          Align(alignment: Alignment.centerLeft, child: IcdCodeLabel(code.code, large: true)),
          const SizedBox(height: SrSpace.m),
          Text(code.title, style: theme.headlineSmall),
          if (detail.ancestors.isNotEmpty) ...[
            const SizedBox(height: SrSpace.s),
            Text(detail.ancestors.first.title, style: theme.bodySmall),
          ],
          if (detail.children.isNotEmpty) ...[
            const SizedBox(height: SrSpace.xl),
            SectionHeader(code.isRange ? 'Входит' : 'Уточнения'),
            const SizedBox(height: SrSpace.s),
            for (final child in detail.children)
              ReferenceRow(
                leading: IcdCodeLabel(child.code),
                title: child.title,
                onTap: onOpenCode == null ? null : () => onOpenCode!(child.code),
              ),
          ],
          if (!code.isRange) ...[
            const SizedBox(height: SrSpace.xl),
            SectionHeader('Клинические рекомендации'),
            const SizedBox(height: SrSpace.s),
            if (detail.guidelines.isEmpty)
              Text('В реестре пока нет КР с этим кодом.', style: theme.bodyMedium!.copyWith(color: c.textMuted)),
            for (final g in detail.guidelines)
              GuidelineRow(g, onTap: onOpenGuideline == null ? null : () => onOpenGuideline!(g)),
          ],
          const SizedBox(height: SrSpace.xl),
          const Disclaimer(),
        ],
      ),
    );
  }
}
