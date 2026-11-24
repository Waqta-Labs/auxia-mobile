import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Visual tone of a card. `selected` and `success` add the colored border the
/// mockups use for the chosen role, the prioritized report or a validated
/// delivery.
enum AppCardTone { normal, deep, selected, success, info }

/// Rounded card of the AuxIA mobile mockups.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tone = AppCardTone.normal,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final AppCardTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (background, border) = switch (tone) {
      AppCardTone.normal => (AppColors.surface, AppColors.outline),
      AppCardTone.deep => (AppColors.surfaceDeep, AppColors.outline),
      AppCardTone.selected => (AppColors.limeContainer, AppColors.lime),
      AppCardTone.success => (AppColors.emeraldContainer, AppColors.emerald),
      AppCardTone.info => (AppColors.surface, AppColors.royalBlue),
    };
    final emphasized =
        tone == AppCardTone.selected ||
        tone == AppCardTone.success ||
        tone == AppCardTone.info;
    final radius = BorderRadius.circular(AppRadius.xl);

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: tone == AppCardTone.selected,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border, width: emphasized ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
