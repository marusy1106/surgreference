import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onStart, required this.onLogin, this.page = 0});

  final VoidCallback onStart;
  final VoidCallback onLogin;

  /// Номер из трёх экранов онбординга (docs/01-mvp.md, 1.4).
  final int page;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      body: AuraBackground(
        aura: Aura.surgery,
        alignment: const Alignment(0.2, -0.55),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: SrSpace.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: SrSpace.l),
                    Text('SurgReference', style: theme.labelLarge!.copyWith(color: c.textMuted)),
                    SizedBox(height: constraints.maxHeight * 0.36),
                    Text('Учись медицине.\nШаг за шагом.', style: theme.headlineLarge),
                    const SizedBox(height: SrSpace.m),
                    Text(
                      'Уроки по клиническим рекомендациям, тесты с разбором каждого ответа и учебные клинические кейсы.',
                      style: theme.bodyMedium!.copyWith(color: c.textMuted),
                    ),
                    const SizedBox(height: SrSpace.xl),
                    StepIndicator(count: 3, current: page, semanticLabel: 'Экран ${page + 1} из 3'),
                    const SizedBox(height: SrSpace.xl),
                    PillButton(label: 'Начать', onPressed: onStart),
                    const SizedBox(height: SrSpace.s),
                    TextButton(
                      onPressed: onLogin,
                      style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size.fromHeight(48)),
                      child: const Text('У меня уже есть аккаунт'),
                    ),
                    const SizedBox(height: SrSpace.l),
                    const Disclaimer(),
                    const SizedBox(height: SrSpace.l),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
