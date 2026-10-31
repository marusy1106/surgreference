import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../../auth/data/models.dart';

final sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>(
  (ref) => ref.watch(authApiProvider).sessions(),
);

/// Устройства, где выполнен вход; любое, кроме текущего, можно отключить.
class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final c = SrColors.of(context);

    Future<void> run(Future<void> Function() action, String done) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
        ref.invalidate(sessionsProvider);
        messenger.showSnackBar(SnackBar(content: Text(done)));
      } on ApiException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }

    return AsyncView(
      value: ref.watch(sessionsProvider),
      onRetry: () => ref.invalidate(sessionsProvider),
      data: (sessions) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(SrSpace.xl),
            children: [
              FormHeader(
                title: 'Сессии и устройства',
                subtitle: 'Если видите незнакомое устройство — отключите его и смените пароль.',
                onBack: context.pop,
              ),
              for (final s in sessions) ...[
                Tile(
                  child: Row(
                    children: [
                      Icon(
                        s.platform == 'ios' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                        color: c.text,
                      ),
                      const SizedBox(width: SrSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.isCurrent ? '${s.deviceName} · это устройство' : s.deviceName,
                              style: theme.labelLarge,
                            ),
                            Text(
                              'Активность ${_date(s.lastUsedAt)}, вход ${_date(s.createdAt)}',
                              style: theme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!s.isCurrent)
                        TextButton(
                          onPressed: () =>
                              run(() => ref.read(authApiProvider).revokeSession(s.id), 'Устройство отключено'),
                          style: TextButton.styleFrom(
                            foregroundColor: c.error,
                            minimumSize: const Size(0, kMinTapTarget),
                          ),
                          child: const Text('Отключить'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: SrSpace.s),
              ],
              if (sessions.length > 1) ...[
                const SizedBox(height: SrSpace.l),
                PillButton(
                  label: 'Отключить все, кроме этого',
                  variant: PillButtonVariant.secondary,
                  showArrow: false,
                  onPressed: () => run(ref.read(authApiProvider).revokeOtherSessions, 'Другие устройства отключены'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
