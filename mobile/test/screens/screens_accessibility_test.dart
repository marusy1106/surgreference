import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'screens.dart';

/// docs/08-design.md, 8.4: шрифт до 200 % без переполнений, тач-цели ≥ 44 pt, подписи у кнопок.
void main() {
  for (final MapEntry(key: name, value: build) in keyScreens.entries) {
    for (final MapEntry(key: theme, value: brightness) in themes.entries) {
      testWidgets('$name · $theme · 200% text has no overflow', (tester) async {
        await pumpThemed(tester, build(), brightness: brightness, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$name meets tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, build(), brightness: Brightness.light);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }
}
