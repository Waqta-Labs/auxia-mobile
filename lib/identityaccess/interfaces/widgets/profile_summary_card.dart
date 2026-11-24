import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/interfaces/widgets/app_card.dart';
import '../../../shared/interfaces/widgets/status_chip.dart';
import '../../domain/model/user_role.dart';
import '../profile_cubit.dart';

/// Profile row of A_06 / A_09: avatar with the initial, name and role badge.
class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = context.select((ProfileCubit cubit) => cubit.state.profile);
    if (profile == null) return const SizedBox.shrink();

    final isBrigadist = profile.role == UserRole.brigadist;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.royalBlue,
            foregroundColor: AppColors.white,
            child: Text(profile.fullName.initial),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              profile.fullName.value,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: StatusChip(
              label: isBrigadist ? l10n.roleBrigadist : l10n.roleCitizen,
              tone: isBrigadist ? StatusTone.info : StatusTone.highlight,
            ),
          ),
        ],
      ),
    );
  }
}
