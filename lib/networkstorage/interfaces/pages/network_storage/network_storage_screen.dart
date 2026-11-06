import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../identityaccess/interfaces/profile_cubit.dart';
import '../../../../identityaccess/interfaces/widgets/profile_summary_card.dart';
import '../../../../l10n/generated/app_localizations.dart';

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
