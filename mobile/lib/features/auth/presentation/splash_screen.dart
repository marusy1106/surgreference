import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Пока восстанавливается сессия.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuraBackground(
        aura: Aura.surgery,
        child: Center(
          child: Semantics(
            label: 'SurgReference, загрузка',
            child: Text('SurgReference', style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
      ),
    );
  }
}
