import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

class AchievementView {
  const AchievementView({required this.title, required this.icon, required this.unlocked});

  final String title;
  final IconData icon;
  final bool unlocked;
}

class ProfileView {
  const ProfileView({
    required this.nickname,
    required this.level,
    required this.xpTotal,
    required this.status,
    required this.university,
    required this.achievements,
  });

  final String nickname;
  final int level;
  final int xpTotal;

  /// Образовательный статус хранится и показывается отдельно от уровня знаний (docs/01-mvp.md, 1.2).
  final String status;
  final String university;
  final List<AchievementView> achievements;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.view, this.onProgress, this.onSetting});

  final ProfileView view;
  final VoidCallback? onProgress;
  final ValueChanged<String>? onSetting;

  static const settings = <(IconData, String)>[
    (Icons.contrast_rounded, 'Тема оформления'),
    (Icons.devices_rounded, 'Сессии и устройства'),
    (Icons.lock_outline_rounded, 'Пароль и email'),
    (Icons.leaderboard_outlined, 'Участие в рейтинге'),
    (Icons.download_rounded, 'Выгрузить мои данные'),
    (Icons.description_outlined, 'Документы и согласия'),
    (Icons.chat_bubble_outline_rounded, 'Обратная связь'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final v = view;
    final unlocked = v.achievements.where((a) => a.unlocked).length;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Row(
              children: [
                InitialsAvatar(v.nickname, size: 64, highlighted: true),
                const SizedBox(width: SrSpace.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.nickname, style: theme.headlineMedium),
                      Text('${v.xpTotal} XP всего', style: theme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SrSpace.xl),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Tile(
                      onTap: onProgress,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TileLabel('Уровень знаний'),
                          const SizedBox(height: SrSpace.m),
                          DotNumber('${v.level}', dotSize: 6, color: c.accent, semanticLabel: 'Уровень ${v.level}'),
                          const Spacer(),
                          const SizedBox(height: SrSpace.m),
                          Text('Прогресс →', style: theme.labelMedium),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: SrSpace.m),
                  Expanded(
                    child: Tile(
                      onTap: () => onSetting?.call('education'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TileLabel('Образование', icon: Icons.school_outlined),
                          const SizedBox(height: SrSpace.m),
                          Text(v.status, style: theme.titleMedium),
                          const SizedBox(height: SrSpace.xs),
                          Text(v.university, style: theme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SrSpace.xl),
            SectionHeader('Достижения · $unlocked из ${v.achievements.length}', actionLabel: 'Все'),
            const SizedBox(height: SrSpace.s),
            Wrap(
              spacing: SrSpace.m,
              runSpacing: SrSpace.m,
              children: [for (final a in v.achievements.take(6)) _Badge(a)],
            ),
            const SizedBox(height: SrSpace.xl),
            const SectionHeader('Настройки'),
            const SizedBox(height: SrSpace.s),
            Container(
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(SrRadius.tile)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, (icon, title)) in settings.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 56, color: c.line),
                    ListTile(
                      minTileHeight: 52,
                      leading: Icon(icon, color: c.text),
                      title: Text(title, style: theme.bodyMedium),
                      trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
                      onTap: () => onSetting?.call(title),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SrSpace.m),
            TextButton(
              onPressed: () => onSetting?.call('delete'),
              style: TextButton.styleFrom(foregroundColor: c.error, minimumSize: const Size.fromHeight(kMinTapTarget)),
              child: const Text('Удалить аккаунт'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.a);

  final AchievementView a;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Semantics(
      label: '${a.title}${a.unlocked ? '' : ', ещё не получено'}',
      excludeSemantics: true,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: a.unlocked ? c.accent : c.surface2),
              child: Icon(a.icon, size: 28, color: a.unlocked ? c.onAccent : c.textMuted),
            ),
            const SizedBox(height: SrSpace.s),
            Text(
              a.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(color: a.unlocked ? c.text : c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
