import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/interfaces/widgets/app_card.dart';

/// Selectable card of a role on A_01: name, tagline, what the role can do and
/// an optional note (the approval required for brigadists).
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.title,
    required this.tagline,
    required this.benefits,
    required this.selected,
    required this.onTap,
    this.note,
  });

  final String title;
  final String tagline;
  final List<String> benefits;
  final bool selected;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = selected ? AppColors.lime : AppColors.skyBlue;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: AppCard(
        tone: selected ? AppCardTone.selected : AppCardTone.normal,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoleAvatar(selected: selected),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleLarge),
                      Text(
                        tagline,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _RadioMark(selected: selected),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, size: 16, color: accent),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(benefit, style: textTheme.bodyMedium)),
                  ],
                ),
              ),
            if (note != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _NoteBadge(text: note!),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleAvatar extends StatelessWidget {
  const _RoleAvatar({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.xl + AppSpacing.xs,
      height: AppSpacing.xl + AppSpacing.xs,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.lime : AppColors.royalContainer,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.onAccent : AppColors.skyBlue,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.lime : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.lime : AppColors.textSecondary,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 18, color: AppColors.onAccent)
          : null,
    );
  }
}

class _NoteBadge extends StatelessWidget {
  const _NoteBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.skyContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 14, color: AppColors.lime),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.skyBlue),
            ),
          ),
        ],
      ),
    );
  }
}
