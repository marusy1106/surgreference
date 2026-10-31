import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

enum LeaderboardMode { students, universities }

enum LeaderboardScope { myUniversity, all }

class LeaderboardRowView {
  const LeaderboardRowView({
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.xp,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final String subtitle;
  final int xp;
  final bool isMe;
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    super.key,
    required this.rows,
    required this.me,
    this.mode = LeaderboardMode.students,
    this.scope = LeaderboardScope.myUniversity,
    this.period = 'Неделя',
    this.onMode,
    this.onScope,
  });

  final List<LeaderboardRowView> rows;

  /// Своё место — закреплено снизу, даже если не попадает в видимую часть.
  final LeaderboardRowView? me;
  final LeaderboardMode mode;
  final LeaderboardScope scope;
  final String period;
  final ValueChanged<LeaderboardMode>? onMode;
  final ValueChanged<LeaderboardScope>? onScope;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(SrSpace.xl),
                children: [
                  Text('Рейтинг', style: theme.headlineMedium),
                  const SizedBox(height: SrSpace.l),
                  SegmentedPill<LeaderboardMode>(
                    segments: const {LeaderboardMode.students: 'Студенты', LeaderboardMode.universities: 'Вузы'},
                    selected: mode,
                    onChanged: (m) => onMode?.call(m),
                  ),
                  const SizedBox(height: SrSpace.m),
                  Wrap(
                    spacing: SrSpace.s,
                    runSpacing: SrSpace.s,
                    children: [
                      if (mode == LeaderboardMode.students) ...[
                        ChipFilter(
                          label: 'Мой вуз',
                          selected: scope == LeaderboardScope.myUniversity,
                          onSelected: (_) => onScope?.call(LeaderboardScope.myUniversity),
                        ),
                        ChipFilter(
                          label: 'Все',
                          selected: scope == LeaderboardScope.all,
                          onSelected: (_) => onScope?.call(LeaderboardScope.all),
                        ),
                      ],
                      ChipFilter(label: period, selected: false, onSelected: (_) {}),
                    ],
                  ),
                  const SizedBox(height: SrSpace.l),
                  for (final row in rows) ...[_Row(row), const SizedBox(height: SrSpace.s)],
                  const SizedBox(height: SrSpace.s),
                  Text(
                    'В рейтинге видны только никнеймы. Участие можно выключить в настройках.',
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
            if (me != null)
              Container(
                padding: const EdgeInsets.fromLTRB(SrSpace.xl, SrSpace.m, SrSpace.xl, SrSpace.m),
                decoration: BoxDecoration(
                  color: c.bg,
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: _Row(me!),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.row);

  final LeaderboardRowView row;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final medal = row.rank <= 3;
    return Semantics(
      label: '${row.rank} место, ${row.name}${row.isMe ? ' (вы)' : ''}, ${row.xp} XP',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SrSpace.l, vertical: SrSpace.m),
        decoration: BoxDecoration(
          color: row.isMe ? Color.alphaBlend(c.accent.withValues(alpha: 0.14), c.surface) : c.surface,
          borderRadius: BorderRadius.circular(SrRadius.tile),
          border: row.isMe ? Border.all(color: c.accent, width: 1.5) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${row.rank}',
                style: theme.titleMedium!.copyWith(color: medal ? c.text : c.textMuted),
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
              ),
            ),
            InitialsAvatar(row.name, size: 40, highlighted: row.isMe),
            const SizedBox(width: SrSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.isMe ? '${row.name} · вы' : row.name, style: theme.labelLarge),
                  Text(row.subtitle, style: theme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: SrSpace.s),
            Text('${row.xp} XP', style: theme.labelLarge),
          ],
        ),
      ),
    );
  }
}
