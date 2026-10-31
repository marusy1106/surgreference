import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surgreference/app/app.dart';
import 'package:surgreference/app/providers.dart';
import 'package:surgreference/core/api/api_client.dart';
import 'package:surgreference/core/api/token_store.dart';
import 'package:surgreference/features/learning/data/demo_learning_repository.dart';

import '../fake_backend.dart';
import '../helpers.dart';

/// Сквозные сценарии по всему приложению: роутер, состояние входа, экраны, демо-контент.
void main() {
  late MemoryTokenStore store;
  late FakeBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = MemoryTokenStore();
    backend = FakeBackend({
      'GET app/config': (_, _) => const FakeResponse(200, {
        'legal_documents': {'pd_processing': '1.0', 'terms': '1.0', 'privacy_policy': '1.0'},
      }),
      'POST auth/login': (_, body) => body!['password'] == 'glass-river-1987'
          ? FakeResponse(200, tokenPair('a1', 'r1'))
          : const FakeResponse(401, {
              'error': {'code': 'invalid_credentials', 'message': 'Неверный email или пароль'},
            }),
      'POST auth/register': (_, _) => const FakeResponse(202, {'status': 'verification_sent'}),
      'POST auth/verify-email': (_, body) => body!['code'] == '123456'
          ? FakeResponse(200, tokenPair('a1', 'r1'))
          : const FakeResponse(400, {
              'error': {
                'code': 'validation_error',
                'message': 'Проверьте введённые данные',
                'fields': {
                  'code': ['Неверный или просроченный код'],
                },
              },
            }),
      'POST auth/refresh': (_, body) =>
          body!['refresh'] == 'r1' ? FakeResponse(200, tokenPair('a2', 'r2')) : unauthorized,
      'GET me': (_, _) => FakeResponse(200, userJson()),
      'POST auth/logout': (_, _) => const FakeResponse(204),
    });
  });

  Future<void> pumpApp(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = phone * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(baseUrl: 'http://test/api/v1/', store: ref.watch(tokenStoreProvider), adapter: backend),
          ),
          learningRepositoryProvider.overrideWith((ref) => DemoLearningRepository(latency: Duration.zero)),
        ],
        child: const SurgReferenceApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Нажать на текст, при необходимости докрутив ленивый список и поставив цель в середину экрана
  /// (иначе её может закрывать нижняя навигация).
  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 200, scrollable: find.byType(Scrollable).first);
    }
    await tester.runAsync(() async {});
    final context = tester.element(target.first);
    await Scrollable.ensureVisible(context, alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  testWidgets('login with a wrong password shows the error, then the right one opens home', (tester) async {
    await pumpApp(tester);
    expect(find.text('Учись медицине.\nШаг за шагом.'), findsOneWidget);

    await tapText(tester, 'У меня уже есть аккаунт');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'anna@example.org');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), 'wrong-password');
    await tapText(tester, 'Войти');
    expect(find.text('Неверный email или пароль'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), 'glass-river-1987');
    await tapText(tester, 'Войти');

    expect(find.text('Привет,'), findsOneWidget);
    expect(find.text('scalpel_anna'), findsOneWidget);
    expect(await store.readRefresh(), 'r1');
  });

  testWidgets('saved refresh token restores the session straight to home', (tester) async {
    await store.writeRefresh('r1');
    await pumpApp(tester);

    expect(find.text('Привет,'), findsOneWidget);
    expect(await store.readRefresh(), 'r2');
  });

  testWidgets('registration needs both consents and ends on the code screen', (tester) async {
    await pumpApp(tester);
    await tapText(tester, 'Начать');

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'anna@example.org');
    await tester.enterText(find.widgetWithText(TextField, 'Никнейм'), 'scalpel_anna');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), 'glass-river-1987');
    await tapText(tester, 'Получить код');
    expect(find.text('Код из письма'), findsNothing, reason: 'button is disabled without consents');

    await tapText(tester, 'Даю согласие на обработку персональных данных');
    await tapText(tester, 'Принимаю пользовательское соглашение и политику конфиденциальности');
    await tapText(tester, 'Получить код');
    expect(find.text('Код из письма'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Неверный или просроченный код'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Привет,'), findsOneWidget);
  });

  testWidgets('quiz: answer all questions, get the review and XP on home', (tester) async {
    final semantics = tester.ensureSemantics();
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Практика');
    await tapText(tester, 'Тест по теме');

    for (var i = 0; i < 5; i++) {
      expect(find.text('${i + 1}/5'), findsOneWidget);
      await tester.tap(find.text('А').first);
      await tester.pump();
      await tapText(tester, 'Ответить');
    }

    expect(find.text('Результат'), findsOneWidget);
    // Первый вариант верен только в вопросах 1 и 2; разбор неверных раскрыт сразу.
    expect(find.text('Ваш ответ — неверно'), findsWidgets);
    expect(find.bySemanticsLabel('Результат 2 из 5'), findsOneWidget);

    await tapText(tester, 'На главную');
    await tapText(tester, 'Главная');
    expect(find.bySemanticsLabel('350 XP за неделю'), findsOneWidget, reason: '340 + 2 × 5 XP');
    semantics.dispose();
  });

  testWidgets('clinical case walks through every step to the summary', (tester) async {
    final semantics = tester.ensureSemantics();
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Практика');
    await tapText(tester, 'Боль в правой подвздошной области');

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Б').first);
      await tester.pumpAndSettle();
      expect(find.text('Есть решение лучше'), findsOneWidget);
      await tapText(tester, 'Следующий шаг');
    }

    expect(find.text('Итог кейса'), findsOneWidget);
    expect(find.bySemanticsLabel('Верных решений 0 из 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('logout from profile returns to the welcome screen', (tester) async {
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Профиль');
    await tapText(tester, 'Выйти из аккаунта');

    expect(find.text('Учись медицине.\nШаг за шагом.'), findsOneWidget);
    expect(await store.readRefresh(), isNull);
  });

  testWidgets('every tab renders at 200% text without layout errors', (tester) async {
    await store.writeRefresh('r1');
    await pumpApp(tester, textScale: 2);
    for (final tab in ['Каталог', 'Практика', 'Рейтинг', 'Профиль', 'Главная']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
