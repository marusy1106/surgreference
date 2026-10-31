import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'pill_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = SrColors.of(context);
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(SrSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: c.surface2, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: c.textMuted),
          ),
          const SizedBox(height: SrSpace.l),
          Text(title, style: theme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: SrSpace.s),
          Text(
            message,
            style: theme.bodyMedium!.copyWith(color: c.textMuted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: SrSpace.xl),
            PillButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}
