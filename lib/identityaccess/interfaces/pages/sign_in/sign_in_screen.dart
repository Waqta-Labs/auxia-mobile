import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/auxia_mark.dart';
import '../../../../shared/interfaces/widgets/bottom_action_area.dart';
import '../../../application/auth_service.dart';
import '../../widgets/validation_messages.dart';
import 'sign_in_cubit.dart';

/// A_10 · Iniciar sesión (Brigadista).
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, this.onBack});

  /// Shown when the screen was opened from another one.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: BlocBuilder<SignInCubit, SignInState>(
        builder: (context, state) {
          final cubit = context.read<SignInCubit>();
          return AutofillGroup(
            child: BottomActionLayout(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AuxiaMark(),
                      const Spacer(),
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          tooltip: l10n.actionBack,
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.signInTitle,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.signInSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('signIn.email'),
                    initialValue: state.email,
                    onChanged: cubit.emailChanged,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      errorText: state.emailError?.message(l10n),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    key: const Key('signIn.password'),
                    onChanged: cubit.passwordChanged,
                    obscureText: !state.passwordVisible,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => cubit.submit(),
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      errorText: state.passwordError?.message(l10n),
                      suffixIcon: IconButton(
                        onPressed: cubit.togglePasswordVisibility,
                        tooltip: state.passwordVisible
                            ? l10n.actionHidePassword
                            : l10n.actionShowPassword,
                        icon: Icon(
                          state.passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _SignInErrorCard(error: state.error!),
                  ],
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: state.submitting ? null : cubit.submit,
                  child: state.submitting
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.onAccent,
                          ),
                        )
                      : Text(l10n.actionSignIn),
                ),
                Text(
                  l10n.signInOfflineNote,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SignInErrorCard extends StatelessWidget {
  const _SignInErrorCard({required this.error});

  final SignInError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (error.kind) {
      SignInErrorKind.notFieldBrigade => l10n.signInNotFieldBrigade,
      SignInErrorKind.noConnection => l10n.signInNoConnection,
      SignInErrorKind.rejected || SignInErrorKind.unexpected =>
        error.message.isEmpty ? l10n.errorUnexpected : error.message,
    };

    return Semantics(
      liveRegion: true,
      child: AppCard(
        tone: AppCardTone.deep,
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.coral),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
