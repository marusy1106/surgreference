import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surgreference/app/theme/theme.dart';

const phone = Size(390, 844);

/// Рисует [child] в теме SurgReference с заданным размером шрифта и выключенной анимацией.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  required Brightness brightness,
  double textScale = 1,
  Size size = phone,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

const themes = {'light': Brightness.light, 'dark': Brightness.dark};

/// Эталонный скриншот с настоящими тенями: по умолчанию тесты рисуют их сплошными, без размытия,
/// и свечение аур на макетах превращается в плашку. Флаг обязан вернуться до конца теста.
Future<void> expectGolden(
  WidgetTester tester,
  Widget child,
  Finder finder,
  String path, {
  required Brightness brightness,
  double textScale = 1,
  Size size = phone,
}) async {
  debugDisableShadows = false;
  try {
    await pumpThemed(tester, child, brightness: brightness, textScale: textScale, size: size);
    await expectLater(finder, matchesGoldenFile(path));
  } finally {
    debugDisableShadows = true;
  }
}
