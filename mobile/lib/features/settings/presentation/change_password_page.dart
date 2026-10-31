import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  ApiException? _error;
  var _busy = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).changePassword(_old.text, _new.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароль изменён. Другие устройства вышли из аккаунта.')));
      context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = {'old_password', 'new_password'};
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(SrSpace.xl),
            children: [
              FormHeader(title: 'Смена пароля', onBack: context.pop),
              PasswordField(controller: _old, label: 'Текущий пароль', errorText: _error?.field('old_password')),
              const SizedBox(height: SrSpace.m),
              PasswordField(
                controller: _new,
                label: 'Новый пароль',
                newPassword: true,
                helperText: 'Не короче 10 символов. Другие устройства выйдут из аккаунта.',
                errorText: _error?.field('new_password'),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null && !_error!.fields.keys.any(shown.contains)) ...[
                const SizedBox(height: SrSpace.m),
                FormMessage(_error!.userMessage),
              ],
              const SizedBox(height: SrSpace.xl),
              PillButton(label: _busy ? 'Сохраняем…' : 'Сменить пароль', onPressed: _busy ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
