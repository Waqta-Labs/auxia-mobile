import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/bottom_action_area.dart';
import '../../../../shared/interfaces/widgets/screen_header.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';
import '../../widgets/validation_messages.dart';
import 'brigade_credential_cubit.dart';

/// A_02 · Registro brigadista · Credencial.
class BrigadeCredentialScreen extends StatelessWidget {
  const BrigadeCredentialScreen({super.key, required this.onBack});

  /// "Volver" and "Volver y cambiar de rol": back to A_01.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<BrigadeCredentialCubit, BrigadeCredentialState>(
      listenWhen: (previous, current) =>
          (!previous.failed && current.failed) ||
          (!previous.cameraFailed && current.cameraFailed),
      listener: (context, state) {
        final message = state.cameraFailed
            ? l10n.idCardCameraError
            : l10n.errorUnexpected;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        body: BlocBuilder<BrigadeCredentialCubit, BrigadeCredentialState>(
          builder: (context, state) {
            final cubit = context.read<BrigadeCredentialCubit>();
            return BottomActionLayout(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(
                    title: l10n.credentialTitle,
                    onBack: onBack,
                    backTooltip: l10n.actionBack,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const StepProgress(steps: 2, completed: 2),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.credentialStep,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('credential.organization'),
                    initialValue: state.organization,
                    onChanged: cubit.organizationChanged,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.organizationLabel,
                      errorText: state.organizationError?.message(l10n),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    key: const Key('credential.brigadeCode'),
                    initialValue: state.brigadeCode,
                    onChanged: cubit.brigadeCodeChanged,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.brigadeCodeLabel,
                      errorText: state.brigadeCodeError?.message(l10n),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _IdCardTile(
                    scanned: state.idCardScanned,
                    label: state.idCardScanned
                        ? l10n.idCardScanned
                        : l10n.scanIdCard,
                    onTap: cubit.scanIdCard,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusChip(
                          label: l10n.statusPendingApproval,
                          tone: StatusTone.progress,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.credentialPendingDetail,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionLabel(l10n.credentialCanDo),
                  const SizedBox(height: AppSpacing.xs),
                  _Permission(text: l10n.credentialCanMissions, allowed: true),
                  _Permission(
                    text: l10n.credentialCanDeliveries,
                    allowed: true,
                  ),
                  _Permission(text: l10n.credentialCannot, allowed: false),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: state.submitting || state.submitted
                      ? null
                      : cubit.submit,
                  child: Text(l10n.actionSendForApproval),
                ),
                OutlinedButton(
                  onPressed: onBack,
                  child: Text(l10n.actionBackChangeRole),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IdCardTile extends StatelessWidget {
  const _IdCardTile({
    required this.scanned,
    required this.label,
    required this.onTap,
  });

  final bool scanned;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: scanned,
      child: AppCard(
        tone: scanned ? AppCardTone.selected : AppCardTone.info,
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              scanned ? Icons.check_box : Icons.check_box_outline_blank,
              color: scanned ? AppColors.lime : AppColors.skyBlue,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            const Icon(Icons.photo_camera_outlined, color: AppColors.skyBlue),
          ],
        ),
      ),
    );
  }
}

class _Permission extends StatelessWidget {
  const _Permission({required this.text, required this.allowed});

  final String text;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final color = allowed ? AppColors.textPrimary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            allowed ? Icons.check : Icons.close,
            size: 16,
            color: allowed ? AppColors.skyBlue : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
