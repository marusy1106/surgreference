import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/routes.dart';
import '../../learning/learning_providers.dart';
import 'catalog_screen.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key});

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  var _filter = CatalogFilter.all;
  var _query = '';

  /// «Освоена» — от 80 % освоения, «начата» — всё, что больше нуля и меньше.
  static const masteredFrom = 0.8;

  bool _matches(DisciplineCardView d) {
    final byFilter = switch (_filter) {
      CatalogFilter.all => true,
      CatalogFilter.started => d.mastery > 0 && d.mastery < masteredFrom,
      CatalogFilter.mastered => d.mastery >= masteredFrom,
    };
    return byFilter && d.title.toLowerCase().contains(_query.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView(
      value: ref.watch(disciplinesProvider),
      onRetry: () => ref.invalidate(disciplinesProvider),
      data: (all) => CatalogScreen(
        disciplines: all.where(_matches).toList(),
        filter: _filter,
        onFilter: (f) => setState(() => _filter = f),
        onSearch: (q) => setState(() => _query = q),
        onOpen: (d) => context.push(Routes.discipline(d.id)),
        onIcd10: () => context.push(Routes.icd10),
        onGuidelines: () => context.push(Routes.guidelines),
      ),
    );
  }
}
