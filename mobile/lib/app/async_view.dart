import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_error.dart';
import '../core/ui/ui.dart';

/// Загрузка → данные или ошибка с кнопкой «Повторить».
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, required this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Не загрузилось',
              message: error is ApiException ? error.userMessage : 'Что-то пошло не так. Попробуйте ещё раз.',
              actionLabel: 'Повторить',
              onAction: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}

/// Пометка демо-данных на экранах, пока контент не приходит с сервера.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SrSpace.m, vertical: SrSpace.xs + 2),
      decoration: ShapeDecoration(color: c.surface2, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 16, color: c.textMuted),
          const SizedBox(width: SrSpace.xs),
          Flexible(
            child: Text(
              'Демо-контент: учебные разделы ещё не подключены к серверу',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
