import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Аватар из первой буквы никнейма: фото пользователей не собираются (docs/04, 4.6).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.nickname, {super.key, this.size = 44, this.highlighted = false});

  final String nickname;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final letter = nickname.isEmpty ? '?' : nickname.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: highlighted ? c.accent : c.surface2),
        child: Text(
          letter,
          textScaler: TextScaler.noScaling,
          style: srTextStyle(size * 0.42, FontWeight.w700).copyWith(color: highlighted ? c.onAccent : c.text),
        ),
      ),
    );
  }
}
