import 'package:flutter/material.dart';
import 'package:surgreference/core/ui/ui.dart';

/// Листы компонентов для эталонных скриншотов и витрины.
final componentSheets = <String, Widget>{
  'buttons': Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PillButton(label: 'Продолжить', onPressed: () {}),
      const SizedBox(height: SrSpace.m),
      PillButton(label: 'На главную', variant: PillButtonVariant.secondary, showArrow: false, onPressed: () {}),
      const SizedBox(height: SrSpace.m),
      const PillButton(label: 'Ответить', onPressed: null),
      const SizedBox(height: SrSpace.m),
      Row(
        children: [
          PillButton(label: 'Начать', expand: false, onPressed: () {}),
          const Spacer(),
          IconCircleButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Назад', onPressed: () {}),
          const SizedBox(width: SrSpace.s),
          IconCircleButton(
            icon: Icons.bookmark_border_rounded,
            semanticLabel: 'В закладки',
            filled: true,
            onPressed: () {},
          ),
        ],
      ),
      const SizedBox(height: SrSpace.l),
      SegmentedPill<int>(segments: const {0: 'Неделя', 1: 'Месяц', 2: 'Год'}, selected: 1, onChanged: (_) {}),
      const SizedBox(height: SrSpace.l),
      Wrap(
        spacing: SrSpace.s,
        runSpacing: SrSpace.s,
        children: [
          ChipFilter(label: 'Все', selected: true, onSelected: (_) {}),
          ChipFilter(label: 'Начатые', selected: false, onSelected: (_) {}),
          ChipFilter(label: 'Освоенные', selected: false, onSelected: (_) {}),
        ],
      ),
    ],
  ),
  'cards': Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final pair in [
        [Aura.surgery, Aura.therapy],
        [Aura.cardiology, Aura.neurology],
        [Aura.pediatrics, Aura.pharmacology],
      ]) ...[
        Row(
          children: [
            for (final (i, aura) in pair.indexed) ...[
              if (i > 0) const SizedBox(width: SrSpace.m),
              Expanded(
                child: AuraCard(
                  aura: aura,
                  glow: false,
                  padding: const EdgeInsets.all(SrSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(aura.name, style: srTextStyle(17, FontWeight.w700)),
                      Text('12 тем', style: srTextStyle(13, FontWeight.w500).copyWith(color: AuraInk.inkMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: SrSpace.m),
      ],
      const SizedBox(height: SrSpace.s),
      Row(
        children: [
          Expanded(
            child: Tile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TileLabel('Серия дней', icon: Icons.local_fire_department_outlined),
                  const SizedBox(height: SrSpace.m),
                  const DotNumber('12', semanticLabel: 'Серия 12 дней'),
                  const SizedBox(height: SrSpace.m),
                  const RulerScale(value: 0.4, ticks: 21, semanticLabel: 'Цель 30 дней', endLabel: 'цель 30'),
                ],
              ),
            ),
          ),
          const SizedBox(width: SrSpace.m),
          const Expanded(
            child: Tile(
              child: Column(
                children: [
                  ProgressRing(value: 0.42, semanticLabel: 'Освоено 42 %', child: Text('42%')),
                  SizedBox(height: SrSpace.m),
                  TileLabel('Освоение'),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: SrSpace.l),
      const StepIndicator(count: 10, current: 3),
      const SizedBox(height: SrSpace.l),
      const LabeledBar(label: 'Хирургия', value: 0.42),
    ],
  ),
  'answers': Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, state) in AnswerState.values.indexed) ...[
        AnswerOption(letter: 'АБВГД'[i], text: 'Вариант ответа: ${state.name}', state: state, onTap: () {}),
        const SizedBox(height: SrSpace.s),
      ],
      const AnswerOption(letter: 'Е', text: 'Множественный выбор', multiple: true, state: AnswerState.selected),
      const SizedBox(height: SrSpace.l),
      const Disclaimer(),
      const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Ничего не нашлось',
        message: 'Попробуйте код МКБ-10 или другое название.',
        actionLabel: 'Сбросить поиск',
      ),
    ],
  ),
  'data': Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const ActivityChart(
        values: [40, 85, 60, 120, 95, 30, 140],
        labels: ['пн', 'ср', 'пт', 'вс'],
        semanticSummary: 'Активность за неделю',
      ),
      const SizedBox(height: SrSpace.xl),
      const Wrap(
        spacing: SrSpace.xl,
        runSpacing: SrSpace.l,
        children: [
          DotNumber('8/10', dotSize: 8, semanticLabel: 'Результат 8 из 10'),
          DotNumber('0:47', dotSize: 5, semanticLabel: 'Осталось 47 секунд'),
          DotNumber('+40', dotSize: 5, semanticLabel: 'Плюс 40 XP'),
          DotNumber('73%', dotSize: 5, semanticLabel: '73 процента'),
        ],
      ),
      const SizedBox(height: SrSpace.xl),
      const RulerScale(value: 0.62, semanticLabel: '620 из 1000 XP', startLabel: 'ур. 7', endLabel: 'ур. 8'),
      const SizedBox(height: SrSpace.l),
      const Row(
        children: [
          InitialsAvatar('scalpel_anna'),
          SizedBox(width: SrSpace.m),
          InitialsAvatar('kocher', highlighted: true),
        ],
      ),
    ],
  ),
};
