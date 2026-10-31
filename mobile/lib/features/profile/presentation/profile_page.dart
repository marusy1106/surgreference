import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/async_view.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/api/api_error.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/documents_sheet.dart';
import '../../learning/learning_providers.dart';
import '../../settings/presentation/theme_sheet.dart';
import 'profile_screen.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void message(String text) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    Future<void> export() async {
      try {
        await ref.read(authApiProvider).requestExport();
        message('Отправим файл с вашими данными на почту в течение нескольких минут.');
      } on ApiException catch (e) {
        message(e.isThrottled ? 'Выгрузку можно запросить раз в сутки.' : e.userMessage);
      }
    }

    Future<void> onAction(ProfileAction action) async {
      switch (action) {
        case ProfileAction.theme:
          await showThemeSheet(context);
        case ProfileAction.sessions:
          await context.push(Routes.sessions);
        case ProfileAction.password:
          await context.push(Routes.password);
        case ProfileAction.export:
          await export();
        case ProfileAction.documents:
          await showDocumentsSheet(context);
        case ProfileAction.delete:
          await context.push(Routes.deleteAccount);
        case ProfileAction.logout:
          await ref.read(authControllerProvider.notifier).logout();
        case ProfileAction.education:
          await context.push(Routes.education);
        case ProfileAction.feedback:
          message('Обратная связь появится в следующем обновлении.');
      }
    }

    return AsyncView(
      value: ref.watch(profileProvider),
      onRetry: () => ref.invalidate(profileProvider),
      data: (view) => ProfileScreen(view: view, onProgress: () => context.push(Routes.progress), onSetting: onAction),
    );
  }
}
