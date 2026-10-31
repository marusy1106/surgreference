@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'screens.dart';

void main() {
  for (final MapEntry(key: name, value: build) in keyScreens.entries) {
    for (final MapEntry(key: theme, value: brightness) in themes.entries) {
      testWidgets('$name · $theme', (tester) async {
        await expectGolden(
          tester,
          build(),
          find.byType(MaterialApp),
          'goldens/${name}_$theme.png',
          brightness: brightness,
        );
      });
    }
  }
}
