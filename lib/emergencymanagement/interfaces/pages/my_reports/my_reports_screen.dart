import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/empty_state.dart';

/// A_05 · Mis reportes: status and sync queue of the citizen's reports.
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

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
            Semantics(
              header: true,
              child: Text(
                l10n.reportsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            EmptyState(icon: Icons.inbox_outlined, message: l10n.reportsEmpty),
          ],
        ),
      ),
    );
  }
}
