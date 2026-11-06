import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../identityaccess/interfaces/profile_cubit.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/brand_header.dart';
import '../../../../shared/interfaces/widgets/empty_state.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';

/// A_07 · Brigadista · Misiones y mapa, the home screen of the brigadist.
class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key, required this.onSignIn});

  /// Opens A_10.
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.select((ProfileCubit cubit) => cubit.state.session);
    final expired = session?.isExpiredAt(DateTime.now()) ?? false;

    final Widget content;
    if (session == null) {
      content = EmptyState(
        icon: Icons.hourglass_top,
        title: l10n.missionsPendingTitle,
        message: l10n.missionsPendingDetail,
        action: FilledButton(
          onPressed: onSignIn,
          child: Text(l10n.actionGoToSignIn),
        ),
      );
    } else if (expired) {
      content = EmptyState(
        icon: Icons.lock_clock_outlined,
        message: l10n.errorSessionExpired,
        action: FilledButton(
          onPressed: onSignIn,
          child: Text(l10n.actionGoToSignIn),
        ),
      );
    } else {
      content = EmptyState(
        icon: Icons.assignment_outlined,
        message: l10n.missionsEmpty,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.md,
          ),
          children: [
            BrandHeader(
              trailing: StatusChip(
                label: l10n.roleBrigadist,
                tone: StatusTone.info,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.missionsAssigned),
            const SizedBox(height: AppSpacing.sm),
            content,
          ],
        ),
      ),
    );
  }
}
