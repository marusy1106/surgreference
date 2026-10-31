import 'package:flutter/material.dart';

import '../core/ui/ui.dart';

enum AppTab {
  home('Главная', Icons.home_outlined, Icons.home_rounded),
  catalog('Каталог', Icons.menu_book_outlined, Icons.menu_book_rounded),
  practice('Практика', Icons.quiz_outlined, Icons.quiz_rounded),
  leaderboard('Рейтинг', Icons.leaderboard_outlined, Icons.leaderboard_rounded),
  profile('Профиль', Icons.person_outline_rounded, Icons.person_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Нижняя навигация из 5 вкладок (docs/01-mvp.md, 1.5): только иконки и точка под активной,
/// как в финансовом референсе. Подписи читает скринридер и показывает подсказка при удержании.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.tab, required this.onTab, required this.child});

  final AppTab tab;
  final ValueChanged<AppTab> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final t in AppTab.values)
                  Expanded(
                    child: _NavItem(tab: t, selected: t == tab, onTap: () => onTab(t)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: Tooltip(
        message: tab.label,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? tab.selectedIcon : tab.icon, color: selected ? c.text : c.textMuted, size: 26),
              const SizedBox(height: SrSpace.xs),
              AnimatedContainer(
                duration: SrMotion.fast,
                width: 4,
                height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? c.text : Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
