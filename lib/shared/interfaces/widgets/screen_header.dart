import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Header of the inner screens of the mockups: round back button, title and
/// an optional trailing widget (for example the report code on A_08).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.backTooltip,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final String? backTooltip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            tooltip: backTooltip,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceHigh,
              fixedSize: const Size.square(AppSpacing.xxxl),
            ),
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Segmented progress of a multi-step flow (A_02 and A_08).
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.steps,
    required this.completed,
    this.activeColor = AppColors.skyBlue,
  });

  final int steps;
  final int completed;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < completed ? activeColor : AppColors.track,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
