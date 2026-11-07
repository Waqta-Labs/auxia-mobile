import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/sync/sync_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../identityaccess/interfaces/profile_cubit.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/domain/geo_point.dart';
import '../../../../shared/interfaces/time_ago.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/brand_header.dart';
import '../../../../shared/interfaces/widgets/empty_state.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';
import '../../../domain/model/mission.dart';
import '../../widgets/mission_card.dart';
import '../../widgets/missions_map.dart';
import 'missions_cubit.dart';

/// A_07 · Brigadista · Misiones y mapa, the home screen of the brigadist.
class MissionsScreen extends StatelessWidget {
  const MissionsScreen({
    super.key,
    required this.onSignIn,
    required this.createCubit,
    required this.onVerifyDelivery,
    required this.onNavigate,
    this.tileUrlTemplate,
    this.tileProvider,
  });

  /// Opens A_10.
  final VoidCallback onSignIn;

  /// Builds the cubit of the signed-in brigadist.
  final MissionsCubit Function() createCubit;

  /// "Verificar entrega": opens A_08 for the mission.
  final void Function(Mission mission) onVerifyDelivery;

  /// Opens turn-by-turn navigation; returns false if it could not.
  final Future<bool> Function(GeoPoint destination) onNavigate;
  final String? tileUrlTemplate;

  /// Serves the tiles downloaded for offline use first.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = context.select((ProfileCubit cubit) => cubit.state.session);

    if (session == null || session.isExpiredAt(DateTime.now())) {
      return _Frame(
        badge: StatusChip(label: l10n.roleBrigadist, tone: StatusTone.info),
        children: [
          SectionLabel(l10n.missionsAssigned),
          const SizedBox(height: AppSpacing.sm),
          EmptyState(
            icon: session == null
                ? Icons.hourglass_top
                : Icons.lock_clock_outlined,
            title: session == null ? l10n.missionsPendingTitle : null,
            message: session == null
                ? l10n.missionsPendingDetail
                : l10n.errorSessionExpired,
            action: FilledButton(
              onPressed: onSignIn,
              child: Text(l10n.actionGoToSignIn),
            ),
          ),
        ],
      );
    }

    return BlocProvider(
      key: ValueKey(session.userId),
      create: (_) => createCubit()..start(),
      child: _MissionsView(
        onVerifyDelivery: onVerifyDelivery,
        onNavigate: onNavigate,
        tileUrlTemplate: tileUrlTemplate,
        tileProvider: tileProvider,
      ),
    );
  }
}

class _MissionsView extends StatelessWidget {
  const _MissionsView({
    required this.onVerifyDelivery,
    required this.onNavigate,
    required this.tileUrlTemplate,
    required this.tileProvider,
  });

  final void Function(Mission mission) onVerifyDelivery;
  final Future<bool> Function(GeoPoint destination) onNavigate;
  final String? tileUrlTemplate;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = context.select(
      (SyncCubit cubit) => cubit.state.network.isOnline,
    );

    return BlocBuilder<MissionsCubit, MissionsState>(
      builder: (context, state) {
        final cubit = context.read<MissionsCubit>();
        final now = cubit.now();
        final brigadeName = state.snapshot.brigadeName;
        final lastRefresh = state.snapshot.lastRefresh;
        final freshness = !online
            ? l10n.missionsOfflineSaved
            : lastRefresh == null
            ? null
            : l10n.missionsUpdated(timeAgo(l10n, lastRefresh, now));

        return _Frame(
          badge: StatusChip(
            label: brigadeName ?? l10n.roleBrigadist,
            tone: StatusTone.info,
          ),
          onRefresh: cubit.refresh,
          children: [
            SizedBox(
              height: 280,
              child: MissionsMap(
                missions: state.openMissions,
                activeMission: state.activeMission,
                myLocation: state.myLocation,
                tileUrlTemplate: tileUrlTemplate,
                tileProvider: tileProvider,
                overlayLabel: l10n.missionsOnMap(state.openMissions.length),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionLabel(
              l10n.missionsAssigned,
              trailing: freshness == null
                  ? null
                  : Text(
                      freshness,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: online
                            ? AppColors.textSecondary
                            : AppColors.emerald,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (state.failure != null && state.missions.isNotEmpty) ...[
              AppCard(
                tone: AppCardTone.deep,
                child: Text(
                  l10n.missionsRefreshError,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.noBrigade)
              EmptyState(
                icon: Icons.group_add_outlined,
                title: l10n.missionsNoBrigadeTitle,
                message: l10n.missionsNoBrigadeDetail,
              )
            else if (state.missions.isEmpty)
              state.loading || state.refreshing
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : EmptyState(
                      icon: Icons.assignment_outlined,
                      message: state.failure == null
                          ? l10n.missionsEmpty
                          : l10n.missionsRefreshError,
                    )
            else
              for (final mission in state.missions) ...[
                MissionCard(
                  mission: mission,
                  myLocation: state.myLocation,
                  now: now,
                  onStartNavigation: () async {
                    await cubit.startNavigation(mission);
                    final location = mission.location;
                    if (location == null) return;
                    final opened = await onNavigate(location);
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.navigationUnavailable)),
                      );
                    }
                  },
                  onVerifyDelivery: () => onVerifyDelivery(mission),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        );
      },
    );
  }
}

/// Layout of A_07: brand header with the brigade badge and the content.
class _Frame extends StatelessWidget {
  const _Frame({required this.badge, required this.children, this.onRefresh});

  final Widget badge;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.md,
      ),
      children: [
        BrandHeader(trailing: badge),
        const SizedBox(height: AppSpacing.md),
        ...children,
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}
