import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Юридические документы. Тексты публикуются перед выходом в магазины (этап 8) — пока здесь их суть.
Future<void> showDocumentsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context).textTheme;
      final c = SrColors.of(context);
      Widget section(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: SrSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.titleMedium),
            const SizedBox(height: SrSpace.xs),
            Text(body, style: theme.bodyMedium!.copyWith(color: c.textMuted)),
          ],
        ),
      );
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(SrSpace.xl, 0, SrSpace.xl, SrSpace.xl),
          children: [
            Text('Документы', style: theme.headlineMedium),
            const SizedBox(height: SrSpace.l),
            section(
              'Согласие на обработку персональных данных',
              'Обрабатываем email, никнейм и, по желанию, имя и учебный профиль — чтобы вести аккаунт и прогресс. '
                  'Данные хранятся на серверах в России. Согласие можно отозвать, удалив аккаунт в настройках.',
            ),
            section(
              'Пользовательское соглашение',
              'Приложение учебное: материалы не заменяют клинические рекомендации и не используются для '
                  'диагностики и лечения реальных пациентов.',
            ),
            section(
              'Политика конфиденциальности',
              'Не собираем телефон, дату рождения, фото и данные о здоровье. Не передаём данные рекламным '
                  'и аналитическим сервисам. Свои данные можно выгрузить или удалить в настройках.',
            ),
            Text('Полные тексты будут опубликованы до выхода приложения в магазины.', style: theme.bodySmall),
          ],
        ),
      );
    },
  );
}
