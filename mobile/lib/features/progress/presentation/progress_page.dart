import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../learning/learning_providers.dart';
import 'progress_screen.dart';

class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  var _period = ProgressPeriod.week;

  @override
  Widget build(BuildContext context) {
    return AsyncView(
      value: ref.watch(progressProvider(_period)),
      onRetry: () => ref.invalidate(progressProvider(_period)),
      data: (view) => ProgressScreen(view: view, onBack: context.pop, onPeriod: (p) => setState(() => _period = p)),
    );
  }
}
