import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

class VerifyCodeScreen extends StatelessWidget {
  const VerifyCodeScreen({
    super.key,
    required this.maskedEmail,
    required this.code,
    required this.resendIn,
    required this.onBack,
    required this.onSubmit,
    this.errorText,
  });

  final String maskedEmail;

  /// Введённые цифры (до 6).
  final String code;

  /// До повторной отправки; null — можно отправить сейчас.
  final Duration? resendIn;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final String? errorText;

  static const length = 6;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    final seconds = resendIn?.inSeconds;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SrSpace.xl),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconCircleButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Назад', onPressed: onBack),
            ),
            const SizedBox(height: SrSpace.xxl),
            Text('Код из письма', style: theme.headlineMedium),
            const SizedBox(height: SrSpace.s),
            Text(
              'Отправили 6 цифр на $maskedEmail. Код действует 15 минут.',
              style: theme.bodyMedium!.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: SrSpace.xl),
            Semantics(
              label: 'Код подтверждения, введено ${code.length} из $length цифр',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < length; i++) ...[
                    if (i > 0) const SizedBox(width: SrSpace.s),
                    Expanded(
                      child: _Cell(digit: i < code.length ? code[i] : null, active: i == code.length),
                    ),
                  ],
                ],
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: SrSpace.m),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: c.error),
                  const SizedBox(width: SrSpace.s),
                  Expanded(
                    child: Text(errorText!, style: theme.labelMedium!.copyWith(color: c.error)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: SrSpace.xl),
            PillButton(label: 'Подтвердить', onPressed: code.length == length ? onSubmit : null),
            const SizedBox(height: SrSpace.m),
            Center(
              child: TextButton(
                onPressed: seconds == null ? () {} : null,
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

class _Cell extends StatelessWidget {
  const _Cell({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    return AspectRatio(
      aspectRatio: 0.8,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? c.accent : c.line, width: active ? 2 : 1),
        ),
        child: digit == null ? null : FittedBox(child: Text(digit!, style: Theme.of(context).textTheme.headlineMedium)),
      ),
    );
  }
}
