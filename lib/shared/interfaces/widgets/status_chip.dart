import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Semantic tone of a status chip (report 6.2.2, status labels).
enum StatusTone {
  /// Saved, pending or informative states (sky blue).
  info,

  /// Work in progress, such as "Transmitiendo" (royal blue).
  progress,

  /// Highlighted states, such as "Priorizado por IA" or the role badge (lime).
  highlight,

  /// Confirmed states: offline mode working, delivered, hash confirmed.
  success,

  /// Critical states: no signal, SOS, failures (coral).
  danger,

  /// Neutral or unavailable states.
  neutral,
}

/// Pill with a status dot and a short label, as used across the mockups.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.info,
    this.showDot = true,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final bool showDot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colorsFor(tone);
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: foreground);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xs - 2),
          ] else if (showDot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Background and foreground colors of each tone.
  static (Color, Color) colorsFor(StatusTone tone) => switch (tone) {
    StatusTone.info => (AppColors.skyContainer, AppColors.skyBlue),
    StatusTone.progress => (AppColors.royalContainer, AppColors.skyBlue),
    StatusTone.highlight => (AppColors.limeContainer, AppColors.lime),
    StatusTone.success => (AppColors.emeraldContainer, AppColors.emerald),
    StatusTone.danger => (AppColors.coralContainer, AppColors.coral),
    StatusTone.neutral => (AppColors.neutralFill, AppColors.textSecondary),
  };
}
