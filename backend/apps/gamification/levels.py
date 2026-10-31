"""Уровни: для перехода на уровень L нужно суммарно 50 · L · (L − 1) XP."""

import math


def xp_for_level(level: int) -> int:
    if level < 1:
        raise ValueError("Уровень начинается с 1")
    return 50 * level * (level - 1)


def level_for_xp(total_xp: int) -> int:
    if total_xp <= 0:
        return 1
    # Наибольший L с 50·L·(L−1) ≤ xp: L = floor((1 + sqrt(1 + xp/12.5)) / 2)
    level = int((1 + math.sqrt(1 + total_xp / 12.5)) // 2)
    # Поправка на погрешность плавающей точки на границах уровней.
    while xp_for_level(level + 1) <= total_xp:
        level += 1
    while xp_for_level(level) > total_xp:
        level -= 1
    return level
