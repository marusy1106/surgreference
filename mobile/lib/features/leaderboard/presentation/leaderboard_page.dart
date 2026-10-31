import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_error.dart';
import '../../learning/data/learning_models.dart';
import '../../learning/learning_providers.dart';
import 'leaderboard_screen.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  var _mode = LeaderboardMode.students;
  var _scope = LeaderboardScope.all;
  var _period = 'week';

  static const periods = {'week': 'Неделя', 'month': 'Месяц', 'all_time': 'Всё время'};

  LeaderboardRowView _row(BoardRow r) =>
      LeaderboardRowView(rank: r.rank, name: r.name, subtitle: r.subtitle, xp: r.xp, isMe: r.isMe);

  Future<void> _optIn(bool value) async {
    try {
      await ref.read(learningRepositoryProvider).setLeaderboardOptIn(value);
      ref.invalidate(leaderboardProvider);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (_mode, _scope, _period);
    return AsyncView(
      value: ref.watch(leaderboardProvider(args)),
      onRetry: () => ref.invalidate(leaderboardProvider(args)),
      data: (board) => LeaderboardScreen(
        rows: [for (final r in board.rows) _row(r)],
        me: board.me == null ? null : _row(board.me!),
        mode: _mode,
        scope: _scope,
        period: periods[_period]!,
        optedIn: board.optedIn,
        note: board.note,
        emptyMessage: board.needsUniversity
            ? 'Укажите вуз в учебном профиле — тогда здесь появятся однокурсники.'
            : _mode == LeaderboardMode.universities
            ? 'Пока ни в одном вузе не набралось достаточно активных участников.'
            : 'За этот период участников ещё нет. Пройдите урок или тест — и вы станете первым.',
        emptyActionLabel: board.needsUniversity ? 'Указать вуз' : null,
        onEmptyAction: () => context.push(Routes.education),
        onMode: (m) => setState(() => _mode = m),
        onScope: (s) => setState(() => _scope = s),
        onPeriod: () => setState(() {
          final keys = periods.keys.toList();
          _period = keys[(keys.indexOf(_period) + 1) % keys.length];
        }),
        onOptIn: _optIn,
      ),
    );
  }
}
