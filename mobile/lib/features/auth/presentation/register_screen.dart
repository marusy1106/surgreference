import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/ui/ui.dart';
import '../application/auth_controller.dart';
import '../data/models.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.onBack, required this.onLogin, required this.onDocuments});

  final VoidCallback onBack;
  final VoidCallback onLogin;
  final VoidCallback onDocuments;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();

  /// Согласие на обработку ПД — отдельное от пользовательского соглашения (152-ФЗ, ст. 9).
  var _pdConsent = false;
  var _termsConsent = false;
  ApiException? _error;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      final versions = await controller.legalVersions();
      await controller.register(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _nickname.text.trim(),
        consents: {
          LegalDocument.pdProcessing: versions[LegalDocument.pdProcessing]!,
          LegalDocument.terms: versions[LegalDocument.terms]!,
          LegalDocument.privacyPolicy: versions[LegalDocument.privacyPolicy]!,
        },
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final ready = _pdConsent && _termsConsent && !_busy;
    final formError = _error == null || _error!.fields.keys.any(_shownFields.contains) ? null : _error!.userMessage;
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(SrSpace.xl),
            children: [
              FormHeader(
                title: 'Регистрация',
                subtitle: 'Нужны только email и никнейм. Имя, телефон и фото не собираем.',
                onBack: widget.onBack,
              ),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Email', errorText: _error?.field('email')),
              ),
              const SizedBox(height: SrSpace.m),
              TextField(
                controller: _nickname,
                autocorrect: false,
                autofillHints: const [AutofillHints.nickname],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Никнейм',
                  helperText: 'Виден в рейтинге. 3–32 символа: буквы, цифры, «_», «.», «-».',
                  helperMaxLines: 2,
                  errorText: _error?.field('display_name'),
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: SrSpace.m),
              PasswordField(
                controller: _password,
                newPassword: true,
                helperText: 'Не короче 10 символов. Удобнее всего — несколько слов.',
                errorText: _error?.field('password'),
              ),
              const SizedBox(height: SrSpace.l),
              _ConsentTile(
                value: _pdConsent,
                onChanged: (v) => setState(() => _pdConsent = v),
                text: 'Даю согласие на обработку персональных данных',
              ),
              _ConsentTile(
                value: _termsConsent,
                onChanged: (v) => setState(() => _termsConsent = v),
                text: 'Принимаю пользовательское соглашение и политику конфиденциальности',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onDocuments,
                  style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(0, kMinTapTarget)),
                  child: const Text('Прочитать документы'),
                ),
              ),
              if (_error?.field('consents') != null) FormMessage(_error!.field('consents')!),
              if (formError != null) FormMessage(formError),
              const SizedBox(height: SrSpace.l),
              PillButton(label: _busy ? 'Отправляем…' : 'Получить код', onPressed: ready ? _submit : null),
              const SizedBox(height: SrSpace.s),
              TextButton(
                onPressed: widget.onLogin,
                style: TextButton.styleFrom(
                  foregroundColor: c.textMuted,
                  minimumSize: const Size.fromHeight(kMinTapTarget),
                ),
                child: Text('Уже есть аккаунт? Войти', style: theme.labelLarge!.copyWith(color: c.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _shownFields = {'email', 'display_name', 'password', 'consents'};
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({required this.value, required this.onChanged, required this.text});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
