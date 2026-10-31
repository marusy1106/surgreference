import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/verify_code_screen.dart';

/// Удаление аккаунта: предупреждение → код из письма → обезличивание (docs/04-auth-security.md, 4.7).
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _code = TextEditingController();
  var _codeSent = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _requestCode() => _run(() async {
    await ref.read(authApiProvider).requestDeletionCode();
    setState(() => _codeSent = true);
  });

  void _delete(String code) => _run(() => ref.read(authControllerProvider.notifier).deleteAccount(code));

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final email = auth is SignedIn ? auth.user.email : '';
    if (_codeSent) {
      return VerifyCodeScreen(
        title: 'Удаление аккаунта',
        actionLabel: 'Удалить аккаунт',
        maskedEmail: maskEmail(email),
        controller: _code,
        resendIn: null,
        errorText: _error,
        busy: _busy,
        onBack: () => setState(() => _codeSent = false),
        onSubmit: _delete,
        onResend: _requestCode,
      );
    }
    final theme = Theme.of(context).textTheme;
    final c = SrColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            FormHeader(title: 'Удаление аккаунта', onBack: context.pop),
            for (final line in const [
              'Email, никнейм, имя и учебный профиль удалятся.',
              'Все устройства выйдут из аккаунта, согласия будут отозваны.',
              'Учебная статистика останется без привязки к вам — восстановить аккаунт будет нельзя.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: SrSpace.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.remove_circle_outline_rounded, size: 20, color: c.error),
                    const SizedBox(width: SrSpace.s),
                    Expanded(child: Text(line, style: theme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: SrSpace.m),
            Text('Хотите сохранить свои данные — сначала запросите выгрузку в профиле.', style: theme.bodySmall),
            if (_error != null) ...[const SizedBox(height: SrSpace.m), FormMessage(_error!)],
            const SizedBox(height: SrSpace.xl),
            PillButton(
              label: _busy ? 'Отправляем…' : 'Получить код подтверждения',
              onPressed: _busy ? null : _requestCode,
            ),
          ],
        ),
      ),
    );
  }
}
