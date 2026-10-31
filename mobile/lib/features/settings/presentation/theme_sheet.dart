import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/ui/ui.dart';

Future<void> showThemeSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final mode = ref.watch(themeModeProvider);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(SrSpace.xl, 0, SrSpace.xl, SrSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Тема оформления', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: SrSpace.m),
              RadioGroup<ThemeMode>(
                groupValue: mode,
                onChanged: (m) => ref.read(themeModeProvider.notifier).set(m!),
                child: const Column(
                  children: [
                    RadioListTile(value: ThemeMode.system, title: Text('Как в системе')),
                    RadioListTile(value: ThemeMode.light, title: Text('Светлая')),
                    RadioListTile(value: ThemeMode.dark, title: Text('Тёмная')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
