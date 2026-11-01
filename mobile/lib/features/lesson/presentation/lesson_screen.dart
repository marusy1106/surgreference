import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../references/data/references_models.dart';
import '../../references/presentation/reference_parts.dart';

/// Блоки структурированного урока (docs/05-learning.md): заголовок, абзац, список, «Важно», таблица
/// и ссылки на справочники (код МКБ-10, клиническая рекомендация).
sealed class LessonBlock {
  const LessonBlock();
}

class HeadingBlock extends LessonBlock {
  const HeadingBlock(this.text);
  final String text;
}

class ParagraphBlock extends LessonBlock {
  const ParagraphBlock(this.text);
  final String text;
}

class BulletsBlock extends LessonBlock {
  const BulletsBlock(this.items);
  final List<String> items;
}

class ImportantBlock extends LessonBlock {
  const ImportantBlock(this.text);
  final String text;
}

class TableBlock extends LessonBlock {
  const TableBlock({required this.header, required this.rows, this.caption});
  final List<String> header;
  final List<List<String>> rows;
  final String? caption;
}

class IcdRefBlock extends LessonBlock {
  const IcdRefBlock({required this.code, required this.title});
  final String code;
  final String title;
}

/// [revised] — КР пересмотрена или заменена после публикации урока: читатель сверяется с актуальной версией.
class GuidelineRefBlock extends LessonBlock {
  const GuidelineRefBlock({
    required this.id,
    required this.title,
    required this.version,
    required this.status,
    required this.revised,
  });
  final int id;
  final String title;
  final String version;
  final GuidelineStatus status;
  final bool revised;
}

class LessonView {
  const LessonView({
    required this.discipline,
    required this.topic,
    required this.title,
    required this.readMinutes,
    required this.blocks,
    required this.sources,
    required this.reviewer,
    required this.updatedAt,
  });

  final String discipline;
  final String topic;
  final String title;
  final int readMinutes;
  final List<LessonBlock> blocks;
  final List<String> sources;
  final String reviewer;
  final String updatedAt;
}

class LessonScreen extends StatelessWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    this.onBack,
    this.onComplete,
    this.onReport,
    this.onOpenIcd,
    this.onOpenGuideline,
  });

  final LessonView lesson;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenIcd;
  final ValueChanged<int>? onOpenGuideline;
  final VoidCallback? onComplete;
  final VoidCallback? onReport;

  /// ~65 знаков в строке при 17 pt.
  static const maxTextWidth = 620.0;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: SrSpace.l),
          child: Center(
            child: IconCircleButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Назад', onPressed: onBack),
          ),
        ),
        title: Text('${lesson.discipline} · ${lesson.topic}', style: theme.labelLarge!.copyWith(color: c.textMuted)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxTextWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(SrSpace.xl, SrSpace.s, SrSpace.xl, SrSpace.xxl),
            children: [
              Text(lesson.title, style: theme.headlineMedium),
              const SizedBox(height: SrSpace.s),
              Text('${lesson.readMinutes} мин чтения', style: theme.bodySmall),
              const SizedBox(height: SrSpace.l),
              for (final block in lesson.blocks) ...[_block(context, block), const SizedBox(height: SrSpace.l)],
              Divider(color: c.line, height: SrSpace.xxl),
              Semantics(header: true, child: Text('Источники', style: theme.titleMedium)),
              const SizedBox(height: SrSpace.s),
              for (final (i, source) in lesson.sources.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: SrSpace.xs),
                  child: Text('${i + 1}. $source', style: theme.bodyMedium!.copyWith(color: c.textMuted)),
                ),
              const SizedBox(height: SrSpace.m),
              Text('Рецензент: ${lesson.reviewer}', style: theme.bodySmall),
              Text('Обновлено ${lesson.updatedAt}', style: theme.bodySmall),
              const SizedBox(height: SrSpace.s),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onReport,
                  style: TextButton.styleFrom(
                    foregroundColor: c.text,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, kMinTapTarget),
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Сообщить об ошибке'),
                ),
              ),
              const SizedBox(height: SrSpace.l),
              PillButton(label: 'Завершить урок', onPressed: onComplete),
              const SizedBox(height: SrSpace.l),
              const Disclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(BuildContext context, LessonBlock block) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return switch (block) {
      HeadingBlock(:final text) => Semantics(header: true, child: Text(text, style: theme.titleLarge)),
      ParagraphBlock(:final text) => Text(text, style: theme.bodyLarge),
      BulletsBlock(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: SrSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: theme.bodyLarge!.copyWith(color: c.accent)),
                  Expanded(child: Text(item, style: theme.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
      ImportantBlock(:final text) => Container(
        padding: const EdgeInsets.all(SrSpace.l),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.warning.withValues(alpha: 0.12), c.surface),
          borderRadius: BorderRadius.circular(SrRadius.tile),
          border: Border(left: BorderSide(color: c.warning, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high_rounded, size: 18, color: c.warning),
                const SizedBox(width: SrSpace.xs),
                Text('Важно', style: theme.labelLarge!.copyWith(color: c.warning)),
              ],
            ),
            const SizedBox(height: SrSpace.s),
            Text(text, style: theme.bodyMedium),
          ],
        ),
      ),
      IcdRefBlock(:final code, :final title) => ReferenceRow(
        leading: IcdCodeLabel(code),
        title: title.isEmpty ? 'МКБ-10' : title,
        subtitle: 'МКБ-10',
        onTap: onOpenIcd == null ? null : () => onOpenIcd!(code),
      ),
      GuidelineRefBlock(:final id, :final title, :final version, :final status, :final revised) => ReferenceRow(
        leading: Container(
          width: kMinTapTarget,
          height: kMinTapTarget,
          decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
          child: Icon(Icons.description_outlined, color: c.text),
        ),
        title: title,
        subtitle: ['Клинические рекомендации', if (version.isNotEmpty) 'версия $version'].join(' · '),
        trailing: revised
            ? Text(
                'КР обновлена после публикации урока — сверяйтесь с актуальной версией',
                style: theme.bodySmall!.copyWith(color: c.warning),
              )
            : GuidelineStatusBadge(status),
        onTap: onOpenGuideline == null ? null : () => onOpenGuideline!(id),
      ),
      TableBlock(:final header, :final rows, :final caption) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null) ...[Text(caption, style: theme.labelLarge), const SizedBox(height: SrSpace.s)],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SrRadius.tile),
                border: Border.all(color: c.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder(horizontalInside: BorderSide(color: c.line)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: c.surface2),
                    children: [for (final h in header) _cell(h, theme.labelMedium!)],
                  ),
                  for (final row in rows) TableRow(children: [for (final cell in row) _cell(cell, theme.bodyMedium!)]),
                ],
              ),
            ),
          ),
        ],
      ),
    };
  }

  Widget _cell(String text, TextStyle style) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: SrSpace.m, vertical: SrSpace.s + 2),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Text(text, style: style),
    ),
  );
}
