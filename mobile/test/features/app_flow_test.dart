import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surgreference/app/app.dart';
import 'package:surgreference/app/providers.dart';
import 'package:surgreference/core/api/api_client.dart';
import 'package:surgreference/core/api/token_store.dart';

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
      ...learningRoutes(),
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
        ],
        child: const SurgReferenceApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Нажать на текст, при необходимости докрутив ленивый список и поставив цель в середину экрана
  /// (иначе её может закрывать нижняя навигация).
  Future<void> tapText(WidgetTester tester, String text) async {
    // Вкладки нижнего меню подписаны только подсказкой (иконки без текста).
    final tab = find.byTooltip(text);
    if (find.text(text).evaluate().isEmpty && tab.evaluate().isNotEmpty) {
      await tester.tap(tab.first);
      await tester.pumpAndSettle();
      return;
    }
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

  testWidgets('quiz: answers go to the server one by one, then the review is shown', (tester) async {
    final semantics = tester.ensureSemantics();
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Практика');
    await tapText(tester, 'Повторить: Острый аппендицит');

    for (var i = 0; i < 5; i++) {
      expect(find.text('${i + 1}/5'), findsOneWidget);
      await tester.tap(find.text('А').first);
      await tester.pump();
      await tapText(tester, 'Ответить');
    }

    expect(backend.log.where((l) => l.startsWith('POST attempts/$quizAttempt/answers')), hasLength(5));
    expect(backend.log.where((l) => l.contains('/finish')), hasLength(1));
    expect(find.text('Результат'), findsOneWidget);
    expect(find.bySemanticsLabel('Результат 2 из 5'), findsOneWidget);
    expect(find.text('Ваш ответ — неверно'), findsWidgets, reason: 'wrong answers are expanded');
    await tester.scrollUntilVisible(find.text('Повторить урок'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Повторить урок'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('mistakes: session from the practice tab, then training of the same discipline', (tester) async {
    final semantics = tester.ensureSemantics();
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Практика');
    await tapText(tester, '5 ошибок — верный ответ уберёт вопрос из списка');

    expect(backend.log, contains(startsWith('POST disciplines/surgery/mistakes')));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('А').first);
      await tester.pump();
      await tapText(tester, 'Ответить');
    }

    expect(find.bySemanticsLabel('Результат 5 из 5'), findsOneWidget);
    expect(find.text('Повторить урок'), findsNothing, reason: 'questions come from several topics');
    await tester.scrollUntilVisible(
      find.text('Тренировка по дисциплине'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapText(tester, 'Тренировка по дисциплине');

    expect(backend.log.last, startsWith('POST disciplines/surgery/training'));
    expect(find.text('Тренировка · Хирургия'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('new user: mistakes are explained, not offered', (tester) async {
    backend.routes.addAll(learningRoutes(newUser: true));
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Практика');

    expect(find.textContaining('откроется после 5 ошибок'), findsOneWidget);
    expect(find.text('10 случайных вопросов, чаще — из слабых тем'), findsNothing);
    expect(find.text('5 вопросов в случайном порядке'), findsOneWidget);
  });

  testWidgets('clinical case: server feedback after each choice, then the summary', (tester) async {
    final semantics = tester.ensureSemantics();
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Практика');
    await tapText(tester, 'Боль в правой подвздошной области');

    await tester.tap(find.text('Б').first);
    await tester.pumpAndSettle();
    expect(find.text('Есть решение лучше'), findsOneWidget);
    expect(find.text('Правильный ответ'), findsOneWidget, reason: 'server named the optimal choice');
    await tapText(tester, 'Следующий шаг');

    await tester.tap(find.text('А').first);
    await tester.pumpAndSettle();
    expect(find.text('Верное решение'), findsOneWidget);
    await tapText(tester, 'Следующий шаг');

    await tester.tap(find.text('А').first);
    await tester.pumpAndSettle();
    await tapText(tester, 'К итогам');

    expect(find.text('Итог кейса'), findsOneWidget);
    expect(find.bySemanticsLabel('Верных решений 2 из 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('catalog → discipline → lesson → complete', (tester) async {
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Каталог');
    await tapText(tester, 'Хирургия');
    expect(find.text('Острый холецистит'), findsOneWidget);
    expect(find.text('Тест по теме'), findsOneWidget);

    await tapText(tester, 'Острый аппендицит: клиническая картина и диагностика');
    expect(find.text('Шкала Альварадо'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('демо-рецензент'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('демо-рецензент'), findsOneWidget);

    await tapText(tester, 'Завершить урок');
    expect(backend.log, contains('POST lessons/1/complete Bearer a2'));
    expect(find.text('Урок пройден'), findsOneWidget);
  });

  testWidgets('references: ICD-10 search → code → guideline → lesson and back via the lesson link', (tester) async {
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Каталог');
    await tapText(tester, 'МКБ-10');
    expect(find.text('Класс XI. Болезни органов пищеварения'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'к35');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Острый аппендицит с генерализованным перитонитом'), findsOneWidget);

    await tapText(tester, 'Острый аппендицит');
    expect(backend.log, contains('GET icd10/K35 Bearer a2'));
    expect(find.text('Уточнения'), findsOneWidget);

    await tapText(tester, 'Острый аппендицит у взрослых');
    expect(find.text('Ключевые положения'), findsOneWidget);
    expect(find.text('Действует'), findsOneWidget);

    await tapText(tester, 'Острый аппендицит: клиническая картина и диагностика');
    expect(find.text('Шкала Альварадо'), findsOneWidget);
    await tapText(tester, 'Острый аппендицит у взрослых');
    expect(find.text('Ключевые положения'), findsOneWidget);
  });

  testWidgets('guidelines registry: status filter and revision notice', (tester) async {
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Каталог');
    await tapText(tester, 'Клинические рекомендации');
    expect(find.text('На пересмотре'), findsWidgets);

    backend.routes['GET guidelines'] = (options, _) => FakeResponse(200, [
      for (final g in fixture('guidelines') as List)
        if ((g as Map)['status'] == options.queryParameters['status']) g,
    ]);
    await tapText(tester, 'На пересмотре');
    expect(find.text('Острый холецистит'), findsOneWidget);
    expect(find.text('Острый аппендицит у взрослых'), findsNothing);
  });

  testWidgets('leaderboard opt-in is sent to the server', (tester) async {
    backend.routes['GET leaderboards/users'] = (_, _) => const FakeResponse(200, {
      'rows': [],
      'me': null,
      'participants': 0,
      'needs_university': false,
      'opted_in': false,
    });
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Рейтинг');
    expect(find.text('Вас нет в рейтинге'), findsOneWidget);

    await tapText(tester, 'Участвовать в рейтинге');

    expect(backend.log, contains('PUT me/leaderboard-participation Bearer a2'));
  });

  testWidgets('education: profile shows the status, switching status resets the specialty', (tester) async {
    Map<String, dynamic>? sent;
    backend.routes['PUT me/education'] = (_, body) {
      sent = body;
      return FakeResponse(200, fixture('education'));
    };
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Профиль');
    expect(find.text('Студент, 5 курс'), findsOneWidget);
    expect(find.text('Сеченовский университет · Лечебное дело'), findsOneWidget);

    await tapText(tester, 'Студент, 5 курс');
    await tapText(tester, 'Ординатор');
    expect(find.text('Выбрать специальность'), findsOneWidget, reason: 'specialitet does not fit a resident');
    await tapText(tester, '2 год');
    await tapText(tester, 'Сохранить');

    expect(sent, containsPair('status', 'resident'));
    expect(sent, containsPair('university_id', 1));
    expect(sent, containsPair('specialty_id', null));
    expect(sent, containsPair('study_year', 2));
    expect(sent, containsPair('course', null));
    expect(find.text('Учебный профиль сохранён'), findsOneWidget);
  });

  testWidgets('new user: home suggests the profile, university comes from search', (tester) async {
    backend.routes.addAll(learningRoutes(newUser: true));
    Map<String, dynamic>? sent;
    backend.routes['PUT me/education'] = (_, body) {
      sent = body;
      return FakeResponse(200, fixture('education'));
    };
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Укажите вуз и курс');

    await tapText(tester, 'Студент');
    await tapText(tester, 'Выбрать вуз');
    await tester.enterText(find.byType(TextField), 'москва');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tapText(tester, 'Сеченовский университет');
    expect(find.text('Сеченовский университет'), findsOneWidget);
    await tapText(tester, 'Выбрать специальность');
    await tapText(tester, 'Лечебное дело');
    await tapText(tester, '3 курс');
    await tapText(tester, 'Сохранить');

    expect(sent, {
      'status': 'student',
      'university_id': 1,
      'faculty_id': null,
      'specialty_id': 1,
      'course': 3,
      'study_year': null,
      'graduation_year': null,
    });
  });

  testWidgets('missing university goes to moderation as a request', (tester) async {
    backend.routes.addAll(learningRoutes(newUser: true));
    await store.writeRefresh('r1');
    await pumpApp(tester);
    await tapText(tester, 'Профиль');
    await tapText(tester, 'Не указан');
    await tapText(tester, 'Врач');
    await tapText(tester, 'Выбрать вуз');
    await tapText(tester, 'Моего вуза нет');
    await tester.enterText(find.widgetWithText(TextField, 'Название вуза'), 'Новый медуниверситет');
    await tester.enterText(find.widgetWithText(TextField, 'Город'), 'Тула');
    await tapText(tester, 'Отправить');

    expect(backend.log, contains(startsWith('POST universities/requests')));
    expect(find.text('Новый медуниверситет'), findsOneWidget);
    expect(find.text('Заявка на проверке'), findsOneWidget);
  });

  testWidgets('education screens at 200% text without layout errors', (tester) async {
    await store.writeRefresh('r1');
    await pumpApp(tester, textScale: 2);
    await tapText(tester, 'Профиль');
    await tapText(tester, 'Студент, 5 курс');
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Сеченовский университет');
    await tester.scrollUntilVisible(find.text('Моего вуза нет'), 200, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('education prompt on home can be dismissed', (tester) async {
    backend.routes.addAll(learningRoutes(newUser: true));
    await store.writeRefresh('r1');
    await pumpApp(tester);
    expect(find.text('Укажите вуз и курс'), findsOneWidget);

    await tester.tap(find.byTooltip('Не сейчас'));
    await tester.pumpAndSettle();

    expect(find.text('Укажите вуз и курс'), findsNothing);
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
      await tester.tap(find.byTooltip(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
