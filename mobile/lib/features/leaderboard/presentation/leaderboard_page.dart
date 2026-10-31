import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/async_view.dart';
import '../../learning/learning_providers.dart';
import 'leaderboard_screen.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  var _mode = LeaderboardMode.students;
  var _scope = LeaderboardScope.myUniversity;

  @override
  Widget build(BuildContext context) {
    final args = (_mode, _scope);
    return AsyncView(
      value: ref.watch(leaderboardProvider(args)),
      onRetry: () => ref.invalidate(leaderboardProvider(args)),
      data: (data) => LeaderboardScreen(
        rows: data.$1,
        me: data.$2,
        mode: _mode,
        scope: _scope,
        onMode: (m) => setState(() => _mode = m),
        onScope: (s) => setState(() => _scope = s),
      ),
    );
  }
}
