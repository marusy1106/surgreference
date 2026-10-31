# SurgReference — mobile

Flutter 3.41, iOS 15+ / Android 8+. Riverpod, go_router, dio, flutter_secure_storage.

- **Авторизация и аккаунт работают с API**: регистрация с согласиями, код из письма, вход, восстановление
  пароля, автоматическое обновление токенов, сессии и устройства, смена пароля, выгрузка данных, удаление аккаунта.
- **Учебные разделы** (каталог, урок, тест с разбором, кейс, прогресс, рейтинг) работают через
  `LearningRepository` на демо-данных — экраны помечены «Демо-контент». Когда на бэкенде появятся эндпоинты
  контента (этап 5), достаточно реализации поверх API и замены `learningRepositoryProvider`.

```
lib/
├── app/              # router (redirect по состоянию входа), providers, тема, нижняя навигация
├── core/api/         # ApiClient (токены, одиночный refresh при 401), ApiException, хранилище refresh-токена
├── core/ui/          # UI-кит: AuraCard, DotNumber, PillButton, AnswerOption… (ui.dart — всё разом)
├── features/auth/    # AuthApi, AuthController (состояния входа), экраны входа и регистрации
├── features/learning/# LearningRepository и демо-реализация
├── features/*/presentation/  # *_screen.dart — вёрстка на готовых данных, *_page.dart — связь с состоянием
└── design_preview/   # демо-данные (вымышленные) для макетов, витрины и демо-репозитория
widgetbook/           # витрина UI-кита
test/                 # контраст, доступность, эталонные скриншоты (goldens/)
```

## Запуск

Нужны Xcode (iOS) и Android Studio (Android) — проверка: `flutter doctor`. Бэкенд — см. `backend/README.md`;
письма с кодами при `CELERY_TASK_ALWAYS_EAGER=true` печатаются в консоль `runserver`.

```bash
flutter run -d ios                                                              # симулятор iOS → localhost:8000
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/  # эмулятор Android
cd widgetbook && flutter run -d chrome                                          # витрина UI-кита
```

HTTP разрешён только к локальным адресам и только в debug (Android) / только localhost (iOS); прод — HTTPS.
Refresh-токен — в Keychain/Keystore, access-токен — только в памяти, бэкап приложения на Android выключен.

## Проверки (то же, что в CI)

```bash
dart format --output=none --set-exit-if-changed lib test widgetbook/lib
flutter analyze
flutter test --exclude-tags golden    # API-клиент, роутер, сквозные сценарии, контраст, шрифт 200 %, тач-цели
flutter test --tags golden            # эталонные скриншоты, только на macOS
```

Изменили вид компонента или экрана намеренно — обновите эталоны и просмотрите их в диффе:

```bash
flutter test --tags golden --update-goldens
```

Тесты рисуют настоящим шрифтом Manrope и с размытыми тенями (`test/flutter_test_config.dart`, `test/helpers.dart`),
поэтому эталоны — это и есть макеты. Допуск сравнения — 1 % пикселей.

## Правила UI

- Цвета — только из `SrColors.of(context)` и `Aura`; новая пара «текст/фон» добавляется в `test/app/contrast_test.dart`.
- Текст на ауре — `AuraInk.ink` / `AuraInk.inkMuted`, не белый.
- Состояние не передаётся одним цветом: у верного/неверного ответа есть иконка и подпись.
- У иконок-кнопок обязателен `semanticLabel`, у чисел точечным шрифтом — тоже.
- Никаких сторонних шрифтовых CDN и SDK: шрифт лежит в `assets/fonts` (лицензия OFL рядом).
