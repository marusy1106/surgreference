import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.onBack, required this.onForgot, required this.onRegister});

  final VoidCallback onBack;
  final VoidCallback onForgot;
  final VoidCallback onRegister;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  ApiException? _error;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = const ApiException(code: 'local', message: 'Введите email и пароль.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(email, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final auth = ref.watch(authControllerProvider);
    final reason = auth is SignedOut ? auth.reason : null;
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(SrSpace.xl),
            children: [
              FormHeader(title: 'Вход', onBack: widget.onBack),
              if (reason != null && _error == null) ...[FormMessage(reason), const SizedBox(height: SrSpace.l)],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Email', errorText: _error?.field('email')),
              ),
              const SizedBox(height: SrSpace.m),
              PasswordField(controller: _password, errorText: _error?.field('password'), onSubmitted: (_) => _submit()),
              if (_error != null && _error!.fields.isEmpty) ...[
                const SizedBox(height: SrSpace.m),
                FormMessage(_error!.userMessage),
              ],
              const SizedBox(height: SrSpace.xl),
              PillButton(label: _busy ? 'Входим…' : 'Войти', onPressed: _busy ? null : _submit),
              const SizedBox(height: SrSpace.s),
              TextButton(
                onPressed: widget.onForgot,
                style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size.fromHeight(kMinTapTarget)),
                child: const Text('Забыли пароль?'),
              ),
              TextButton(
                onPressed: widget.onRegister,
                style: TextButton.styleFrom(
                  foregroundColor: c.textMuted,
                  minimumSize: const Size.fromHeight(kMinTapTarget),
                ),
                child: const Text('Нет аккаунта? Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
