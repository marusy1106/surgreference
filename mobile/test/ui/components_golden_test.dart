@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'sheets.dart';

void main() {
  for (final MapEntry(key: sheet, value: widget) in componentSheets.entries) {
    for (final MapEntry(key: theme, value: brightness) in themes.entries) {
      for (final scale in [1.0, 2.0]) {
        final percent = (scale * 100).round();
        testWidgets('$sheet · $theme · $percent%', (tester) async {
          const key = ValueKey('sheet');
          await expectGolden(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: key,
                  child: Builder(
                    builder: (context) => ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Padding(padding: const EdgeInsets.all(24), child: widget),
                    ),
                  ),
                ),
              ),
            ),
            find.byKey(key),
            'goldens/${sheet}_${theme}_$percent.png',
            brightness: brightness,
            textScale: scale,
            size: const Size(390, 3000),
          );
        });
      }
    }
  }
}
