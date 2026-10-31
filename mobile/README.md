# SurgReference — mobile

Flutter 3.41, iOS 15+ / Android 8+. Этап 4: дизайн-система, UI-кит и макеты ключевых экранов на демо-данных
(данные из API подключаются на этапе 5).

```
lib/
├── app/theme/        # токены (SrColors, Aura, отступы, радиусы), типографика Manrope, ThemeData
├── app/shell.dart    # нижняя навигация из 5 вкладок
├── core/ui/          # UI-кит: AuraCard, DotNumber, PillButton, AnswerOption… (ui.dart — всё разом)
├── features/*/presentation/  # экраны; принимают готовые данные, сами ничего не загружают
└── design_preview/   # кликабельный прототип и демо-данные (вымышленные)
widgetbook/           # витрина UI-кита
test/                 # контраст, доступность, эталонные скриншоты (goldens/)
```

## Посмотреть

```bash
flutter run                                   # прототип: онбординг → код → вкладки
cd widgetbook && flutter run -d chrome        # витрина: компоненты с настройками, экраны, тема, шрифт до 200 %
```

## Проверки (то же, что в CI)

```bash
dart format --output=none --set-exit-if-changed lib test widgetbook/lib
flutter analyze
flutter test --exclude-tags golden    # контраст токенов, нет переполнений при шрифте 200 %, тач-цели ≥ 44, подписи кнопок
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
