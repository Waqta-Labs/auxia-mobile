import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sync/sync_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/brand_header.dart';
import '../../../../shared/interfaces/widgets/connectivity_badge.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';
import '../../../domain/model/citizen_report.dart';
import '../../widgets/sos_widgets.dart';
import 'sos_cubit.dart';

/// A_03 · SOS 1-Toque, the home screen of the citizen.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key, required this.onSosSaved});

  /// Opens the optional detail (A_04) of the report just saved.
  final void Function(CitizenReport report) onSosSaved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final online = context.select(
      (SyncCubit cubit) => cubit.state.network.isOnline,
    );

    return BlocListener<SosCubit, SosState>(
      listenWhen: (previous, current) =>
          previous.lastReport != current.lastReport ||
          (!previous.failed && current.failed),
      listener: (context, state) {
        if (state.failed) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.errorUnexpected)));
          return;
        }
        onSosSaved(state.lastReport!);
      },
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<SosCubit, SosState>(
            builder: (context, state) {
              final cubit = context.read<SosCubit>();
              return ListView(
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
                  const SizedBox(height: AppSpacing.md),
                  const Center(child: ConnectivityBadge()),
                  if (!online) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.offlineSavedLocally,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.skyBlue,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.sosTitle,
                      textAlign: TextAlign.center,
                      style: MediaQuery.sizeOf(context).width < 360
                          ? textTheme.headlineSmall
                          : textTheme.headlineMedium,
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
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    // The SOS must be visible without scrolling, also on
                    // small phones: its size follows the screen height.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (MediaQuery.sizeOf(context).height * 0.36)
                            .clamp(176.0, 320.0),
                      ),
                      child: SosButton(
                        semanticLabel: l10n.sosButtonSemantics(
                          categoryLabel(l10n, state.category),
                        ),
                        onPressed: state.sending
                            ? null
                            : () {
                                HapticFeedback.heavyImpact();
                                cubit.sendSos();
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CategorySelector(
                    selected: state.category,
                    onSelected: cubit.selectCategory,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _GpsCard(state: state, onRetry: cubit.locate),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "GPS -12.0464, -77.0428 · guardado" and "3 reportes en cola".
class _GpsCard extends StatelessWidget {
  const _GpsCard({required this.state, required this.onRetry});

  final SosState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (text, color) = switch (state.gps) {
      GpsStatus.fixed => (
        l10n.gpsSaved(state.location!.format()),
        AppColors.emerald,
      ),
      GpsStatus.locating => (l10n.gpsLocating, AppColors.skyBlue),
      GpsStatus.unavailable => (l10n.gpsUnavailable, AppColors.coral),
      GpsStatus.denied => (l10n.gpsPermissionDenied, AppColors.coral),
    };

    return AppCard(
      tone: AppCardTone.deep,
      onTap: state.gps == GpsStatus.fixed ? null : onRetry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(text, style: textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.sosQueue(state.queued),
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.lime,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
