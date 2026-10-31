import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';

/// Сброс пароля в два шага: email → код из письма и новый пароль.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, required this.onBack, required this.onDone});

  final VoidCallback onBack;

  /// Пароль сменён: все сессии завершены, нужно войти заново.
  final VoidCallback onDone;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  var _codeSent = false;
  var _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
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
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sendCode() => _run(() async {
    await ref.read(authApiProvider).forgotPassword(_email.text.trim());
    if (mounted) setState(() => _codeSent = true);
  });

  void _reset() => _run(() async {
    await ref.read(authApiProvider).resetPassword(_email.text.trim(), _code.text, _password.text);
    widget.onDone();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            FormHeader(
              title: _codeSent ? 'Новый пароль' : 'Восстановление пароля',
              subtitle: _codeSent
                  ? 'Если аккаунт с адресом ${maskEmail(_email.text.trim())} есть, мы отправили на него код.'
                  : 'Пришлём код на почту, с которой вы регистрировались.',
              onBack: _codeSent ? () => setState(() => _codeSent = false) : widget.onBack,
            ),
            if (!_codeSent) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: 'Email', errorText: _error?.field('email')),
              ),
            ] else ...[
              CodeInput(controller: _code, enabled: !_busy),
              const SizedBox(height: SrSpace.l),
              PasswordField(
                controller: _password,
                label: 'Новый пароль',
                newPassword: true,
                helperText: 'Не короче 10 символов. После смены все устройства выйдут из аккаунта.',
                errorText: _error?.field('new_password'),
              ),
            ],
            if (_error != null && _error!.field('email') == null && _error!.field('new_password') == null) ...[
              const SizedBox(height: SrSpace.m),
              FormMessage(_error!.userMessage),
            ],
            const SizedBox(height: SrSpace.xl),
            PillButton(
              label: _busy ? 'Подождите…' : (_codeSent ? 'Сменить пароль' : 'Получить код'),
              onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
            ),
          ],
        ),
      ),
    );
  }
}
