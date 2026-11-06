import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/brand_header.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';

/// A_03 · SOS 1-Toque, the home screen of the citizen.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

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
                label: l10n.roleCitizen,
                tone: StatusTone.highlight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.sosTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.sosSubtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
