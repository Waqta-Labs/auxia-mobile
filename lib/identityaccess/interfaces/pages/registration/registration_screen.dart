import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/auxia_mark.dart';
import '../../../../shared/interfaces/widgets/bottom_action_area.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../domain/model/user_role.dart';
import '../../widgets/role_card.dart';
import '../../widgets/validation_messages.dart';
import 'registration_cubit.dart';

/// A_01 · Registro y selección de rol.
class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key, required this.onContinueToCredential});

  /// Opens A_02 with the validated name and phone.
  final void Function(PendingRegistration pending) onContinueToCredential;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<RegistrationCubit, RegistrationState>(
      listenWhen: (previous, current) =>
          previous.outcome != current.outcome || current.failed,
      listener: (context, state) {
        if (state.failed) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.errorUnexpected)));
        }
        if (state.outcome == RegistrationOutcome.continueToCredential) {
          final pending = context.read<RegistrationCubit>().pending;
          if (pending != null) onContinueToCredential(pending);
        }
      },
      child: Scaffold(
        body: BlocBuilder<RegistrationCubit, RegistrationState>(
          builder: (context, state) {
            final cubit = context.read<RegistrationCubit>();
            return BottomActionLayout(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuxiaMark(),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.registrationTitle,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.registrationSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('registration.fullName'),
                    initialValue: state.fullName,
                    onChanged: cubit.nameChanged,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(
                      labelText: l10n.fullNameLabel,
                      errorText: state.nameError?.message(l10n),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    key: const Key('registration.phone'),
                    initialValue: state.phone,
                    onChanged: cubit.phoneChanged,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-()]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.phoneLabel,
                      errorText: state.phoneError?.message(l10n),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionLabel(l10n.roleQuestion),
                  const SizedBox(height: AppSpacing.sm),
                  RoleCard(
                    title: l10n.roleCitizen,
                    tagline: l10n.roleCitizenTagline,
                    benefits: [
                      l10n.roleCitizenBenefitSos,
                      l10n.roleCitizenBenefitStatus,
                    ],
                    selected: state.role == UserRole.citizen,
                    onTap: () => cubit.roleSelected(UserRole.citizen),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  RoleCard(
                    title: l10n.roleBrigadist,
                    tagline: l10n.roleBrigadistTagline,
                    benefits: [
                      l10n.roleBrigadistBenefitMissions,
                      l10n.roleBrigadistBenefitBlockchain,
                    ],
                    note: l10n.roleBrigadistApproval,
                    selected: state.role == UserRole.brigadist,
                    onTap: () => cubit.roleSelected(UserRole.brigadist),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: state.submitting ? null : cubit.submit,
                  child: Text(l10n.actionContinue),
                ),
                Text(
                  l10n.registrationLocalNote,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
