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

/// Нижняя навигация из 5 вкладок (docs/01-mvp.md, 1.5). На этапе 5 оборачивается в StatefulShellRoute.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.tab, required this.onTab, required this.child});

  final AppTab tab;
  final ValueChanged<AppTab> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: SrColors.of(context).line)),
        ),
        child: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (i) => onTab(AppTab.values[i]),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final t in AppTab.values)
              NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
          ],
        ),
      ),
    );
  }
}
