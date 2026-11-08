import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Asks to confirm an action in a bottom sheet, as the design system asks
/// instead of centered dialogs (6.1.2). True when the user confirms.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final textTheme = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: textTheme.titleLarge),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(action),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
