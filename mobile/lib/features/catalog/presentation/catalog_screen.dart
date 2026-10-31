import 'package:flutter/material.dart';

import '../../../core/text/plural.dart';
import '../../../core/ui/ui.dart';

class DisciplineCardView {
  const DisciplineCardView({
    required this.id,
    required this.title,
    required this.aura,
    required this.topics,
    required this.mastery,
  });

  final String id;
  final String title;
  final Aura aura;
  final int topics;
  final double mastery;
}

enum CatalogFilter { all, started, mastered }

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    super.key,
    required this.disciplines,
    this.filter = CatalogFilter.all,
    this.onFilter,
    this.onOpen,
    this.onReferences,
    this.onSearch,
    this.banner,
  });

  final List<DisciplineCardView> disciplines;
  final CatalogFilter filter;
  final ValueChanged<CatalogFilter>? onFilter;
  final ValueChanged<DisciplineCardView>? onOpen;
  final VoidCallback? onReferences;
  final ValueChanged<String>? onSearch;

  /// Над списком: например, пометка демо-контента.
  final Widget? banner;

  static const _filterLabels = {
    CatalogFilter.all: 'Все',
    CatalogFilter.started: 'Начатые',
    CatalogFilter.mastered: 'Освоенные',
  };

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Text('Каталог', style: theme.headlineMedium),
            if (banner != null) ...[
              const SizedBox(height: SrSpace.m),
              Align(alignment: Alignment.centerLeft, child: banner),
            ],
            const SizedBox(height: SrSpace.l),
            TextField(
              onChanged: onSearch,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Поиск по дисциплинам',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: SrSpace.l),
            Wrap(
              spacing: SrSpace.s,
              runSpacing: SrSpace.s,
              children: [
                for (final MapEntry(key: f, value: label) in _filterLabels.entries)
                  ChipFilter(label: label, selected: f == filter, onSelected: (_) => onFilter?.call(f)),
              ],
            ),
            const SizedBox(height: SrSpace.xl),
            if (disciplines.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Ничего не нашлось',
                message: 'Попробуйте другое название или сбросьте фильтр.',
              ),
            for (var i = 0; i < disciplines.length; i += 2) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _DisciplineCard(disciplines[i], onOpen)),
                    const SizedBox(width: SrSpace.m),
                    Expanded(
                      child: i + 1 < disciplines.length
                          ? _DisciplineCard(disciplines[i + 1], onOpen)
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SrSpace.m),
            ],
            const SizedBox(height: SrSpace.m),
            SectionHeader('Справочники'),
            const SizedBox(height: SrSpace.s),
            for (final (icon, title, subtitle) in [
              (Icons.tag_rounded, 'МКБ-10', 'Поиск по коду и названию'),
              (Icons.description_outlined, 'Клинические рекомендации', 'Версии и статус документа'),
            ]) ...[
              Tile(
                onTap: onReferences,
                child: Row(
                  children: [
                    Container(
                      width: kMinTapTarget,
                      height: kMinTapTarget,
                      decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
                      child: Icon(icon, color: c.text),
                    ),
                    const SizedBox(width: SrSpace.m),
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
              ),
              const SizedBox(height: SrSpace.s),
            ],
          ],
        ),
      ),
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard(this.d, this.onOpen);

  final DisciplineCardView d;
  final ValueChanged<DisciplineCardView>? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final percent = (d.mastery * 100).round();
    return AuraCard(
      aura: d.aura,
      glow: false,
      minHeight: 168,
      padding: const EdgeInsets.all(SrSpace.l),
      onTap: onOpen == null ? null : () => onOpen!(d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressRing(
            value: d.mastery,
            size: 44,
            stroke: 4,
            color: AuraInk.ink,
            semanticLabel: 'Освоено $percent %',
            child: Text('$percent', style: theme.labelSmall!.copyWith(color: AuraInk.ink)),
          ),
          const SizedBox(height: SrSpace.l),
          Text(d.title, style: theme.titleMedium!.copyWith(color: AuraInk.ink, fontSize: 18)),
          Text(
            '${d.topics} ${plural(d.topics, 'тема', 'темы', 'тем')}',
            style: theme.labelMedium!.copyWith(color: AuraInk.inkMuted),
          ),
        ],
      ),
    );
  }
}
