import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/ui.dart';
import '../data/references_models.dart';

/// Шапка экранов справочников: круглая «Назад» и подпись раздела, как у урока.
PreferredSizeWidget referenceAppBar(BuildContext context, String label, VoidCallback? onBack) {
  final c = SrColors.of(context);
  return AppBar(
    leadingWidth: 64,
    leading: Padding(
      padding: const EdgeInsets.only(left: SrSpace.l),
      child: Center(
        child: IconCircleButton(icon: Icons.arrow_back_rounded, semanticLabel: 'Назад', onPressed: onBack),
      ),
    ),
    title: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: c.textMuted)),
  );
}

class GuidelineStatusBadge extends StatelessWidget {
  const GuidelineStatusBadge(this.status, {super.key});

  final GuidelineStatus status;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final color = switch (status) {
      GuidelineStatus.active => c.success,
      GuidelineStatus.underRevision => c.warning,
      GuidelineStatus.superseded || GuidelineStatus.withdrawn => c.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SrSpace.s + 2, vertical: SrSpace.xs),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.14), c.surface),
        borderRadius: BorderRadius.circular(SrRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: SrSpace.xs + 2),
          Text(status.label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: c.text)),
        ],
      ),
    );
  }
}

/// Код МКБ-10 моноширинной «плашкой»: K35.8.
class IcdCodeLabel extends StatelessWidget {
  const IcdCodeLabel(this.code, {super.key, this.large = false});

  final String code;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Container(
      constraints: BoxConstraints(minWidth: large ? 0 : 72),
      padding: EdgeInsets.symmetric(horizontal: SrSpace.s + 2, vertical: large ? SrSpace.s : SrSpace.xs),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(SrRadius.pill)),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: (large ? theme.headlineSmall : theme.labelLarge)!.copyWith(
          color: c.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Строка списка: код (или иконка) слева, название, шеврон.
class ReferenceRow extends StatelessWidget {
  const ReferenceRow({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap});

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: SrSpace.s),
      child: Tile(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: SrSpace.l, vertical: SrSpace.m),
        child: Row(
          children: [
            leading,
            const SizedBox(width: SrSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.bodyLarge),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: theme.bodySmall),
                  ],
                  if (trailing != null) ...[const SizedBox(height: SrSpace.s), trailing!],
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class GuidelineRow extends StatelessWidget {
  const GuidelineRow(this.guideline, {super.key, this.onTap});

  final GuidelineBrief guideline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final g = guideline;
    return ReferenceRow(
      leading: Container(
        width: kMinTapTarget,
        height: kMinTapTarget,
        decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
        child: Icon(Icons.description_outlined, color: c.text),
      ),
      title: g.title,
      subtitle: [
        if (g.icdCodes.isNotEmpty) g.icdCodes.join(', '),
        if (g.version.isNotEmpty) 'версия ${g.version}',
      ].join(' · '),
      trailing: GuidelineStatusBadge(g.status),
      onTap: onTap,
    );
  }
}

/// Поиск над списком справочника.
class ReferenceSearchField extends StatelessWidget {
  const ReferenceSearchField({super.key, required this.hint, this.onChanged, this.initial = ''});

  final String hint;
  final String initial;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initial,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded)),
  );
}

/// Результаты поиска: загрузка и ошибка — внутри списка, чтобы поле поиска не пропадало.
List<Widget> asyncRows<T>(
  BuildContext context,
  AsyncValue<List<T>> value, {
  required Widget Function(T item) row,
  required String emptyTitle,
  required String emptyMessage,
  VoidCallback? onRetry,
}) {
  if (value.hasError && !value.hasValue) {
    return [
      EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Не загрузилось',
        message: 'Проверьте соединение и попробуйте ещё раз.',
        actionLabel: onRetry == null ? null : 'Повторить',
        onAction: onRetry,
      ),
    ];
  }
  final items = value.valueOrNull;
  if (items == null) {
    return const [
      Padding(
        padding: EdgeInsets.all(SrSpace.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    ];
  }
  if (items.isEmpty) {
    return [EmptyState(icon: Icons.search_off_rounded, title: emptyTitle, message: emptyMessage)];
  }
  return [for (final item in items) row(item)];
}

/// Ссылка на текст КР открывается во внешнем браузере; только https.
Future<void> openSource(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final opened = uri != null && uri.scheme == 'https' && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Не удалось открыть ссылку: $url')));
  }
}
