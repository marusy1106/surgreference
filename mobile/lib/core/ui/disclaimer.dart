import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Обязательная пометка учебного характера контента (онбординг, уроки, кейсы).
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.text = defaultText});

  static const defaultText =
      'Учебное приложение. Не используется для диагностики и лечения реальных пациентов. '
      'Все клинические кейсы вымышлены.';

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
        const SizedBox(width: SrSpace.s),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}
