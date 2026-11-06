import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Small uppercase heading in sky blue that opens each block of a screen,
/// such as "¿CUÁL ES TU ROL?" or "COLA LOCAL · 4 REPORTES".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppColors.skyBlue),
    );

    return Semantics(
      header: true,
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: trailing!),
              ],
            ),
    );
  }
}
