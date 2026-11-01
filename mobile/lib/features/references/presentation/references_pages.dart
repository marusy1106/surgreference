import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/routes.dart';
import '../data/references_models.dart';
import '../references_providers.dart';
import 'guideline_screens.dart';
import 'icd_screens.dart';
import 'reference_parts.dart';

/// Запрос уходит, когда пользователь перестал печатать.
mixin _Debounced<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const delay = Duration(milliseconds: 300);

  var query = '';
  Timer? _timer;

  void search(String value) {
    _timer?.cancel();
    _timer = Timer(delay, () => setState(() => query = value.trim()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class IcdSearchPage extends ConsumerStatefulWidget {
  const IcdSearchPage({super.key});

  @override
  ConsumerState<IcdSearchPage> createState() => _IcdSearchPageState();
}

class _IcdSearchPageState extends ConsumerState<IcdSearchPage> with _Debounced {
  @override
  Widget build(BuildContext context) => IcdSearchScreen(
    results: ref.watch(icdSearchProvider(query)),
    query: query,
    onSearch: search,
    onOpen: (code) => context.push(Routes.icdCode(code.code)),
    onBack: context.pop,
    onRetry: () => ref.invalidate(icdSearchProvider(query)),
  );
}

class IcdCodePage extends ConsumerWidget {
  const IcdCodePage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(icdCodeProvider(code)),
    onRetry: () => ref.invalidate(icdCodeProvider(code)),
    data: (detail) => IcdCodeScreen(
      detail: detail,
      onOpenCode: (other) => context.push(Routes.icdCode(other)),
      onOpenGuideline: (g) => context.push(Routes.guideline(g.id)),
      onBack: context.pop,
    ),
  );
}

class GuidelinesPage extends ConsumerStatefulWidget {
  const GuidelinesPage({super.key});

  @override
  ConsumerState<GuidelinesPage> createState() => _GuidelinesPageState();
}

class _GuidelinesPageState extends ConsumerState<GuidelinesPage> with _Debounced {
  GuidelineStatus? _status;

  @override
  Widget build(BuildContext context) {
    final args = (query: query, status: _status);
    return GuidelinesScreen(
      results: ref.watch(guidelineSearchProvider(args)),
      query: query,
      status: _status,
      onSearch: search,
      onStatus: (s) => setState(() => _status = s),
      onOpen: (g) => context.push(Routes.guideline(g.id)),
      onBack: context.pop,
      onRetry: () => ref.invalidate(guidelineSearchProvider(args)),
    );
  }
}

class GuidelinePage extends ConsumerWidget {
  const GuidelinePage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(guidelineProvider(id)),
    onRetry: () => ref.invalidate(guidelineProvider(id)),
    data: (detail) => GuidelineScreen(
      detail: detail,
      onOpenCode: (code) => context.push(Routes.icdCode(code)),
      onOpenLesson: (lesson) => context.push(Routes.lesson('${lesson.id}')),
      onOpenSource: () => openSource(context, detail.sourceUrl),
      onBack: context.pop,
    ),
  );
}
