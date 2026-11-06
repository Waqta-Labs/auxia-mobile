import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/empty_state.dart';
import '../../../../shared/interfaces/widgets/screen_header.dart';

/// A_08 · Verificar entrega (QR, signature and photo, Blockchain).
class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key});

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
            ScreenHeader(title: l10n.deliveryTitle),
            const SizedBox(height: AppSpacing.lg),
            EmptyState(
              icon: Icons.qr_code_scanner,
              message: l10n.deliveryEmpty,
            ),
          ],
        ),
      ),
    );
  }
}
