import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sync/sync_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../identityaccess/interfaces/profile_cubit.dart';
import '../../../../identityaccess/interfaces/widgets/profile_summary_card.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/time_ago.dart';
import '../../../../shared/interfaces/widgets/connectivity_badge.dart';

/// A_06 / A_09 · Red y almacenamiento, the settings of both roles.
class NetworkStorageScreen extends StatelessWidget {
  const NetworkStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = context.select(
      (ProfileCubit cubit) => cubit.state.isSignedIn,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.md,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.settingsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const ProfileSummaryCard(),
            const SizedBox(height: AppSpacing.sm),
            const _SyncStatusRow(),
            const SizedBox(height: AppSpacing.md),
            const _SyncNowButton(),
            const SizedBox(height: AppSpacing.xl),
            if (signedIn) ...[
              OutlinedButton(
                onPressed: () => _confirmSignOut(context),
                child: Text(l10n.actionSignOut),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton(
              onPressed: () => _confirmChangeRole(context),
              child: Text(l10n.actionChangeRole),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final profileCubit = context.read<ProfileCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await profileCubit.signOut();
  }

  Future<void> _confirmChangeRole(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final profileCubit = context.read<ProfileCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeRoleConfirmTitle),
        content: Text(l10n.changeRoleConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionConfirmChangeRole),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await profileCubit.reset();
  }
}

/// "Modo Offline Activo · Última sync: hace 3 h" and the pending writes.
class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SyncCubit>().state;
    final lastSync = state.lastSyncAt;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const ConnectivityBadge(),
        Text(
          lastSync == null
              ? l10n.lastSyncNever
              : l10n.lastSync(timeAgo(l10n, lastSync, DateTime.now())),
          style: style,
        ),
        Text(l10n.syncPending(state.pending), style: style),
      ],
    );
  }
}

/// "Sincronizar ahora" (A_06 / A_09).
class _SyncNowButton extends StatelessWidget {
  const _SyncNowButton();

  @override
  Widget build(BuildContext context) {
    final running = context.select((SyncCubit cubit) => cubit.state.running);
    return OutlinedButton(
      onPressed: running ? null : () => context.read<SyncCubit>().retryAll(),
      child: Text(AppLocalizations.of(context).actionSyncNow),
    );
  }
}
