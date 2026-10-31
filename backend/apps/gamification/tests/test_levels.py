import pytest

from apps.gamification.levels import level_for_xp, xp_for_level


@pytest.mark.parametrize(("level", "xp"), [(1, 0), (2, 100), (3, 300), (5, 1000), (10, 4500), (20, 19000)])
def test_xp_for_level_matches_spec(level, xp):
    assert xp_for_level(level) == xp


@pytest.mark.parametrize(
    ("xp", "level"), [(-5, 1), (0, 1), (99, 1), (100, 2), (299, 2), (300, 3), (4499, 9), (4500, 10), (19000, 20)]
)
def test_level_for_xp(xp, level):
    assert level_for_xp(xp) == level


def test_level_for_xp_is_inverse_on_boundaries():
    for level in range(1, 200):
        assert level_for_xp(xp_for_level(level)) == level
        if level > 1:
            assert level_for_xp(xp_for_level(level) - 1) == level - 1
