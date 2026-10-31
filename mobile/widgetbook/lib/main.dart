import 'package:flutter/material.dart';
import 'package:surgreference/app/shell.dart';
import 'package:surgreference/core/ui/ui.dart';
import 'package:surgreference/design_preview/demo_data.dart';
import 'package:surgreference/features/auth/presentation/verify_code_screen.dart';
import 'package:surgreference/features/cases/presentation/case_step_screen.dart';
import 'package:surgreference/features/catalog/presentation/catalog_screen.dart';
import 'package:surgreference/features/home/presentation/home_screen.dart';
import 'package:surgreference/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:surgreference/features/lesson/presentation/lesson_screen.dart';
import 'package:surgreference/features/onboarding/presentation/onboarding_screen.dart';
import 'package:surgreference/features/profile/presentation/profile_screen.dart';
import 'package:surgreference/features/progress/presentation/progress_screen.dart';
import 'package:surgreference/features/quiz/presentation/quiz_result_screen.dart';
import 'package:surgreference/features/quiz/presentation/quiz_screen.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const UiKit());

/// Витрина UI-кита: компоненты с настройками и ключевые экраны в обеих темах и при шрифте до 200 %.
class UiKit extends StatelessWidget {
  const UiKit({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Тёмная', data: buildTheme(Brightness.dark)),
            WidgetbookTheme(name: 'Светлая', data: buildTheme(Brightness.light)),
          ],
        ),
        TextScaleAddon(min: 1, max: 2, divisions: 4),
        ViewportAddon([IosViewports.iPhone13, AndroidViewports.samsungGalaxyA50, Viewports.none]),
      ],
      directories: [
        WidgetbookFolder(name: 'Компоненты', children: _components),
        WidgetbookFolder(name: 'Экраны', children: _screens),
      ],
    );
  }
}

/// Компонент с одним сценарием.
WidgetbookComponent _one(String name, WidgetbookUseCase useCase) =>
    WidgetbookComponent(name: name, useCases: [useCase]);

Widget _padded(Widget child) => Center(
  child: SingleChildScrollView(padding: const EdgeInsets.all(SrSpace.xl), child: child),
);

Aura _auraKnob(BuildContext context) =>
    context.knobs.object.dropdown(label: 'Аура', options: Aura.values, labelBuilder: (a) => a.name);

final _components = <WidgetbookNode>[
  WidgetbookComponent(
    name: 'PillButton',
    useCases: [
      WidgetbookUseCase(
        name: 'Варианты',
        builder: (context) => _padded(
          PillButton(
            label: context.knobs.string(label: 'Текст', initialValue: 'Продолжить'),
            variant: context.knobs.object.segmented(
              label: 'Вариант',
              options: PillButtonVariant.values,
              labelBuilder: (v) => v.name,
            ),
            showArrow: context.knobs.boolean(label: 'Стрелка', initialValue: true),
            expand: context.knobs.boolean(label: 'Во всю ширину', initialValue: true),
            onPressed: context.knobs.boolean(label: 'Неактивна') ? null : () {},
          ),
        ),
      ),
    ],
  ),
  _one(
    'IconCircleButton',
    WidgetbookUseCase(
      name: 'По умолчанию',
      builder: (context) => _padded(
        IconCircleButton(
          icon: Icons.bookmark_border_rounded,
          semanticLabel: 'В закладки',
          filled: context.knobs.boolean(label: 'Залитая'),
          onPressed: () {},
        ),
      ),
    ),
  ),
  _one('SegmentedPill', WidgetbookUseCase(name: 'Период', builder: (context) => _padded(const _SegmentedDemo()))),
  _one(
    'ChipFilter',
    WidgetbookUseCase(
      name: 'По умолчанию',
      builder: (context) => _padded(
        ChipFilter(
          label: context.knobs.string(label: 'Текст', initialValue: 'Начатые'),
          selected: context.knobs.boolean(label: 'Выбран'),
          onSelected: (_) {},
        ),
      ),
    ),
  ),
  _one(
    'AuraCard',
    WidgetbookUseCase(
      name: 'Дисциплина',
      builder: (context) => _padded(
        AuraCard(
          aura: _auraKnob(context),
          glow: context.knobs.boolean(label: 'Свечение', initialValue: true),
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Продолжить урок · Хирургия'),
              const SizedBox(height: SrSpace.s),
              Text(
                context.knobs.string(label: 'Заголовок', initialValue: 'Острый аппендицит: диагностика'),
                style: Theme.of(context).textTheme.titleLarge!.copyWith(color: AuraInk.ink),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  _one(
    'AuraBackground',
    WidgetbookUseCase(
      name: 'Онбординг',
      builder: (context) => AuraBackground(aura: _auraKnob(context)),
    ),
  ),
  _one(
    'Tile',
    WidgetbookUseCase(
      name: 'Серия дней',
      builder: (context) {
        final days = context.knobs.int.slider(label: 'Дней', initialValue: 12, min: 0, max: 30);
        return _padded(
          SizedBox(
            width: 180,
            child: Tile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TileLabel('Серия дней', icon: Icons.local_fire_department_outlined),
                  const SizedBox(height: SrSpace.m),
                  DotNumber('$days', color: SrColors.of(context).accent, semanticLabel: 'Серия $days дней'),
                  const SizedBox(height: SrSpace.m),
                  RulerScale(value: days / 30, ticks: 21, semanticLabel: 'Цель 30 дней', endLabel: 'цель 30'),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ),
  _one(
    'DotNumber',
    WidgetbookUseCase(
      name: 'Число',
      builder: (context) {
        final value = context.knobs.string(label: 'Значение', initialValue: '8/10');
        return _padded(
          DotNumber(
            value,
            dotSize: context.knobs.double.slider(label: 'Размер точки', initialValue: 8, min: 3, max: 14),
            showUnlit: context.knobs.boolean(label: 'Неактивные точки', initialValue: true),
            semanticLabel: value,
          ),
        );
      },
    ),
  ),
  _one(
    'RulerScale',
    WidgetbookUseCase(
      name: 'Таймер',
      builder: (context) => _padded(
        RulerScale(
          value: context.knobs.double.slider(label: 'Значение', initialValue: 0.6, min: 0, max: 1),
          ticks: context.knobs.int.slider(label: 'Делений', initialValue: 41, min: 11, max: 61),
          semanticLabel: 'Шкала',
          startLabel: 'ур. 7',
          endLabel: 'ур. 8',
        ),
      ),
    ),
  ),
  _one(
    'ProgressRing',
    WidgetbookUseCase(
      name: 'Освоение',
      builder: (context) {
        final value = context.knobs.double.slider(label: 'Значение', initialValue: 0.42, min: 0, max: 1);
        return _padded(
          ProgressRing(
            value: value,
            size: 96,
            semanticLabel: 'Освоено ${(value * 100).round()} %',
            child: Text('${(value * 100).round()}%'),
          ),
        );
      },
    ),
  ),
  _one(
    'StepIndicator',
    WidgetbookUseCase(
      name: 'Вопросы теста',
      builder: (context) {
        final count = context.knobs.int.slider(label: 'Шагов', initialValue: 10, min: 1, max: 20);
        final current = context.knobs.int.slider(label: 'Текущий', initialValue: 3, min: 1, max: 20);
        return _padded(StepIndicator(count: count, current: (current - 1).clamp(0, count - 1)));
      },
    ),
  ),
  _one(
    'AnswerOption',
    WidgetbookUseCase(
      name: 'Состояния',
      builder: (context) => _padded(
        AnswerOption(
          letter: 'Б',
          text: context.knobs.string(label: 'Текст', initialValue: 'УЗИ брюшной полости'),
          state: context.knobs.object.dropdown(
            label: 'Состояние',
            options: AnswerState.values,
            labelBuilder: (s) => s.name,
          ),
          multiple: context.knobs.boolean(label: 'Множественный выбор'),
          onTap: () {},
        ),
      ),
    ),
  ),
  _one(
    'ActivityChart',
    WidgetbookUseCase(
      name: 'Месяц',
      builder: (context) => _padded(
        ActivityChart(
          values: Demo.progress.activity,
          labels: Demo.progress.activityLabels,
          semanticSummary: Demo.progress.activitySummary,
        ),
      ),
    ),
  ),
  _one(
    'LabeledBar',
    WidgetbookUseCase(
      name: 'Освоение',
      builder: (context) => _padded(
        LabeledBar(
          label: 'Хирургия',
          value: context.knobs.double.slider(label: 'Значение', initialValue: 0.42, min: 0, max: 1),
        ),
      ),
    ),
  ),
  _one(
    'EmptyState',
    WidgetbookUseCase(
      name: 'Поиск',
      builder: (context) => _padded(
        EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Ничего не нашлось',
          message: 'Попробуйте код МКБ-10 или другое название.',
          actionLabel: 'Сбросить поиск',
          onAction: () {},
        ),
      ),
    ),
  ),
  _one('Disclaimer', WidgetbookUseCase(name: 'По умолчанию', builder: (context) => _padded(const Disclaimer()))),
];

class _SegmentedDemo extends StatefulWidget {
  const _SegmentedDemo();

  @override
  State<_SegmentedDemo> createState() => _SegmentedDemoState();
}

class _SegmentedDemoState extends State<_SegmentedDemo> {
  var _period = ProgressPeriod.week;

  @override
  Widget build(BuildContext context) => SegmentedPill<ProgressPeriod>(
    segments: const {ProgressPeriod.week: 'Неделя', ProgressPeriod.month: 'Месяц', ProgressPeriod.year: 'Год'},
    selected: _period,
    onChanged: (p) => setState(() => _period = p),
  );
}

Widget _tab(AppTab tab, Widget child) => AppShell(tab: tab, onTab: (_) {}, child: child);

WidgetbookComponent _screen(String name, Widget Function() build) =>
    _one(name, WidgetbookUseCase(name: 'Демо', builder: (_) => build()));

final _screens = <WidgetbookNode>[
  _screen('Онбординг', () => OnboardingScreen(onStart: () {}, onLogin: () {})),
  _screen(
    'Код подтверждения',
    () => VerifyCodeScreen(
      maskedEmail: 'a•••@example.org',
      code: '4821',
      resendIn: const Duration(seconds: 42),
      errorText: 'Неверный код. Осталось 4 попытки.',
      onBack: () {},
      onSubmit: () {},
    ),
  ),
  _screen('Главная', () => _tab(AppTab.home, const HomeScreen(view: Demo.home))),
  _screen('Каталог', () => _tab(AppTab.catalog, const CatalogScreen(disciplines: Demo.disciplines))),
  _screen('Урок', () => const LessonScreen(lesson: Demo.lesson)),
  _screen('Тест', () => QuizScreen(question: Demo.quizQuestion, onSelect: (_) {}, onAnswer: () {})),
  _screen('Результат теста', () => const QuizResultScreen(result: Demo.quizResult)),
  _screen('Шаг кейса', () => const CaseStepScreen(view: Demo.caseStep)),
  _screen('Прогресс', () => ProgressScreen(view: Demo.progress, onBack: () {})),
  _screen('Рейтинг', () => _tab(AppTab.leaderboard, const LeaderboardScreen(rows: Demo.leaderboard, me: Demo.me))),
  _screen('Профиль', () => _tab(AppTab.profile, const ProfileScreen(view: Demo.profile))),
];
