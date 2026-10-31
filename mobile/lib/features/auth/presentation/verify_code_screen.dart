import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Экран ввода кода из письма: подтверждение email и удаление аккаунта.
class VerifyCodeScreen extends StatelessWidget {
  const VerifyCodeScreen({
    super.key,
    required this.maskedEmail,
    required this.controller,
    required this.resendIn,
    required this.onBack,
    required this.onSubmit,
    this.onResend,
    this.errorText,
    this.busy = false,
    this.autofocus = true,
    this.title = 'Код из письма',
    this.actionLabel = 'Подтвердить',
  });

  final String maskedEmail;
  final TextEditingController controller;

  /// До повторной отправки; null — можно отправить сейчас.
  final Duration? resendIn;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onResend;
  final String? errorText;
  final bool busy;
  final bool autofocus;
  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final seconds = resendIn?.inSeconds;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            FormHeader(
              title: title,
              subtitle: 'Отправили 6 цифр на $maskedEmail. Код действует 15 минут.',
              onBack: onBack,
            ),
            CodeInput(controller: controller, autofocus: autofocus, enabled: !busy, onCompleted: onSubmit),
            if (errorText != null) ...[const SizedBox(height: SrSpace.m), FormMessage(errorText!)],
            const SizedBox(height: SrSpace.xl),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) => PillButton(
                label: busy ? 'Проверяем…' : actionLabel,
                onPressed: value.text.length == CodeInput.length && !busy ? () => onSubmit(value.text) : null,
              ),
            ),
            const SizedBox(height: SrSpace.m),
            Center(
              child: TextButton(
                onPressed: seconds == null && !busy ? onResend : null,
                style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(0, kMinTapTarget)),
                child: Text(
                  seconds == null
                      ? 'Отправить код ещё раз'
                      : 'Отправить ещё раз через ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
