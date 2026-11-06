import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/sync/sync_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../identityaccess/domain/model/user_role.dart';
import '../../../../identityaccess/interfaces/profile_cubit.dart';
import '../../../../identityaccess/interfaces/widgets/profile_summary_card.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/format_bytes.dart';
import '../../../../shared/interfaces/time_ago.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/connectivity_badge.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../application/offline_maps_service.dart';
import 'network_storage_cubit.dart';

/// A_06 / A_09 · Red y almacenamiento, the settings of both roles.
class NetworkStorageScreen extends StatelessWidget {
  const NetworkStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = context.select((ProfileCubit cubit) => cubit.state);
    final brigadist = profile.role == UserRole.brigadist;

    return BlocListener<NetworkStorageCubit, NetworkStorageState>(
      listenWhen: (previous, current) =>
          current.notice != null && previous.notice != current.notice,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.notice == MapsNotice.noSpace
                ? l10n.mapsNoSpace
                : l10n.mapsDownloadFailed,
          ),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<NetworkStorageCubit, NetworkStorageState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                  vertical: AppSpacing.md,
                ),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.settingsTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const ProfileSummaryCard(),
                  const SizedBox(height: AppSpacing.sm),
                  const _SyncStatusRow(),
                  const SizedBox(height: AppSpacing.lg),
                  SectionLabel(
                    brigadist ? l10n.mapsBrigadeTitle : l10n.mapsCitizenTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MapsUsageCard(state: state),
                  const SizedBox(height: AppSpacing.sm),
                  if (!state.loading && state.regions.isEmpty)
                    Text(
                      l10n.mapsNoRegions,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  for (final region in state.regions) ...[
                    _RegionCard(region: region),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SectionLabel(l10n.localDatabase),
                  const SizedBox(height: AppSpacing.sm),
                  _DatabaseCard(state: state, brigadist: brigadist),
                  const SizedBox(height: AppSpacing.lg),
                  SectionLabel(l10n.languageTitle),
                  const SizedBox(height: AppSpacing.sm),
                  const _LanguageSelector(),
                  const SizedBox(height: AppSpacing.xl),
                  if (profile.isSignedIn) ...[
                    OutlinedButton(
                      onPressed: () => _confirmSignOut(context),
                      child: Text(l10n.actionSignOut),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  OutlinedButton(
                    onPressed: () => _confirmChangeRole(context),
                    child: Text(l10n.actionChangeRole),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final profileCubit = context.read<ProfileCubit>();
    final confirmed = await _confirm(
      context,
      title: l10n.signOutConfirmTitle,
      body: l10n.signOutConfirmBody,
      action: l10n.actionSignOut,
    );
    if (confirmed) await profileCubit.signOut();
  }

  Future<void> _confirmChangeRole(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final profileCubit = context.read<ProfileCubit>();
    final confirmed = await _confirm(
      context,
      title: l10n.changeRoleConfirmTitle,
      body: l10n.changeRoleConfirmBody,
      action: l10n.actionConfirmChangeRole,
    );
    if (confirmed) await profileCubit.reset();
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

/// "Modo Offline Activo · Última sync: hace 3 h".
class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lastSync = context.select(
      (SyncCubit cubit) => cubit.state.lastSyncAt,
    );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const ConnectivityBadge(),
        Text(
          lastSync == null
              ? l10n.lastSyncNever
              : l10n.lastSync(timeAgo(l10n, lastSync, DateTime.now())),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// "Mapas descargados · 218 MB de 2 GB".
class _MapsUsageCard extends StatelessWidget {
  const _MapsUsageCard({required this.state});

  final NetworkStorageState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ratio = state.budgetBytes == 0
        ? 0.0
        : (state.usedBytes / state.budgetBytes).clamp(0.0, 1.0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.mapsDownloaded, style: textTheme.titleSmall),
              ),
              Text(
                l10n.mapsUsage(
                  formatBytes(state.usedBytes),
                  formatBytes(state.budgetBytes),
                ),
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.skyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(value: ratio, minHeight: 8),
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final RegionState region;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<NetworkStorageCubit>();
    final size = formatBytes(region.bytes);
    final name = region.region.assigned
        ? l10n.regionAssigned(region.region.name)
        : region.region.name;

    final (status, statusColor) = region.available
        ? (l10n.regionAvailable(size), AppColors.emerald)
        : region.downloading
        ? (
            l10n.regionDownloading(size, region.percent),
            AppColors.textSecondary,
          )
        : region.started
        ? (l10n.regionPaused(size, region.percent), AppColors.textSecondary)
        : (l10n.regionNotDownloaded(size), AppColors.textSecondary);

    final Widget action;
    if (region.available) {
      action = _RegionButton(
        label: l10n.actionDelete,
        background: AppColors.neutralFill,
        foreground: AppColors.textPrimary,
        onPressed: () => cubit.delete(region.region),
      );
    } else if (region.downloading) {
      action = _RegionButton(
        label: l10n.actionPause,
        background: AppColors.royalBlue,
        foreground: AppColors.white,
        onPressed: () => cubit.pause(region.region),
      );
    } else {
      action = _RegionButton(
        label: region.started ? l10n.actionResume : l10n.actionDownload,
        background: AppColors.lime,
        foreground: AppColors.onAccent,
        onPressed: () => cubit.download(region.region),
      );
    }

    return AppCard(
      tone: region.available ? AppCardTone.success : AppCardTone.normal,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: AppSpacing.xxl,
            height: AppSpacing.xxl,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              region.available ? Icons.download_done : Icons.map_outlined,
              color: region.available ? AppColors.emerald : AppColors.skyBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  status,
                  style: textTheme.bodySmall?.copyWith(color: statusColor),
                ),
                if (region.downloading) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  LinearProgressIndicator(value: region.percent / 100),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          action,
        ],
      ),
    );
  }
}

class _RegionButton extends StatelessWidget {
  const _RegionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(96, AppSpacing.minTouchTarget + 8),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        textStyle: Theme.of(context).textTheme.titleSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      child: Text(label),
    );
  }
}

/// "Base de datos local · SQLite": four figures and "Sincronizar ahora".
class _DatabaseCard extends StatelessWidget {
  const _DatabaseCard({required this.state, required this.brigadist});

  final NetworkStorageState state;
  final bool brigadist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stats = state.stats;
    final running = context.select((SyncCubit cubit) => cubit.state.running);
    final integrity = stats.intact ? l10n.integrityOk : l10n.integrityFailed;

    final tiles = brigadist
        ? [
            (l10n.statLocalMissions, '${stats.missions}', null),
            (l10n.statEvidenceToUpload, '${stats.evidenceToUpload}', null),
            (l10n.statBlockchainQueue, '${stats.blockchainQueue}', null),
            (l10n.statIntegrity, integrity, stats.intact),
          ]
        : [
            (l10n.statLocalReports, '${stats.citizenReports}', null),
            (l10n.statPendingSync, '${stats.pendingSync}', null),
            (l10n.statDbSize, formatBytes(stats.databaseBytes), null),
            (l10n.statIntegrity, integrity, stats.intact),
          ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < tiles.length; row += 2) ...[
            if (row > 0) const SizedBox(height: AppSpacing.xs),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = row; i < row + 2; i++) ...[
                    if (i > row) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _StatTile(
                        label: tiles[i].$1,
                        value: tiles[i].$2,
                        ok: tiles[i].$3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: running
                ? null
                : () async {
                    await context.read<SyncCubit>().retryAll();
                    if (context.mounted) {
                      await context.read<NetworkStorageCubit>().refreshStats();
                    }
                  },
            child: Text(l10n.actionSyncNow),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.ok});

  final String label;
  final String value;

  /// For the integrity tile: green when OK, coral when not.
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = switch (ok) {
      true => AppColors.emerald,
      false => AppColors.coral,
      null => AppColors.textPrimary,
    };
    return AppCard(
      tone: AppCardTone.deep,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'es', label: Text(l10n.languageSpanish)),
        ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
      ],
      selected: {locale.languageCode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          context.read<LocaleCubit>().change(Locale(selection.first)),
    );
  }
}
