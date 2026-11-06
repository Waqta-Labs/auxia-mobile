import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/brand_header.dart';
import '../../../../shared/interfaces/widgets/empty_state.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';

/// A_07 · Brigadista · Misiones y mapa, the home screen of the brigadist.
class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
            EmptyState(
              icon: Icons.hourglass_top,
              title: l10n.missionsPendingTitle,
              message: l10n.missionsPendingDetail,
            ),
          ],
        ),
      ),
    );
  }
}
