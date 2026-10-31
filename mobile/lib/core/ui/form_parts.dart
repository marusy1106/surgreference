import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Ошибка формы целиком (не привязанная к полю): иконка + текст, не только цвет.
class FormMessage extends StatelessWidget {
  const FormMessage(this.text, {super.key, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final tone = isError ? c.error : c.success;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 18, color: tone),
          const SizedBox(width: SrSpace.s),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: tone)),
          ),
        ],
      ),
    );
  }
}

/// Поле пароля с кнопкой «показать».
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Пароль',
    this.errorText,
    this.helperText,
    this.newPassword = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? helperText;

  /// Подсказка менеджеру паролей: новый пароль, а не текущий.
  final bool newPassword;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  var _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      textInputAction: widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        helperText: widget.helperText,
        helperMaxLines: 3,
        errorMaxLines: 4,
        suffixIcon: IconButton(
          tooltip: _visible ? 'Скрыть пароль' : 'Показать пароль',
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}

/// Заголовок экрана формы с кнопкой «назад».
class FormHeader extends StatelessWidget {
  const FormHeader({super.key, required this.title, this.subtitle, this.onBack});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: _BackButton(onBack: onBack!),
          ),
        const SizedBox(height: SrSpace.xl),
        Semantics(header: true, child: Text(title, style: theme.headlineMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: SrSpace.s),
          Text(subtitle!, style: theme.bodyMedium!.copyWith(color: c.textMuted)),
        ],
        const SizedBox(height: SrSpace.xl),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return Semantics(
      button: true,
      label: 'Назад',
      child: Material(
        color: c.surface2,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onBack,
          child: SizedBox.square(dimension: 48, child: Icon(Icons.arrow_back_rounded, color: c.text)),
        ),
      ),
    );
  }
}

/// Скрыть адрес частично: anna@example.org → a•••@example.org.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email[0]}•••${email.substring(at)}';
}
