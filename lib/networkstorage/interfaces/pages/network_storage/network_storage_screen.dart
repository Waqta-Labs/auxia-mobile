import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/maps/map_region.dart';
import '../../../../core/sync/sync_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../emergencymanagement/interfaces/mesh_cubit.dart';
import '../../../../identityaccess/domain/model/user_role.dart';
import '../../../../identityaccess/interfaces/profile_cubit.dart';
import '../../../../identityaccess/interfaces/widgets/profile_summary_card.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/format_bytes.dart';
import '../../../../shared/interfaces/time_ago.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/confirm_sheet.dart';
import '../../../../shared/interfaces/widgets/connectivity_badge.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../../shared/interfaces/widgets/sync_channels.dart';
import 'network_storage_cubit.dart';

/// A_06 / A_09 · Red y almacenamiento, the settings of both roles.
class NetworkStorageScreen extends StatelessWidget {
  const NetworkStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = context.select((ProfileCubit cubit) => cubit.state);
    final brigadist = profile.role == UserRole.brigadist;

    return Scaffold(
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
                SectionLabel(l10n.channelsTitle),
                const SizedBox(height: AppSpacing.sm),
                const _ChannelsCard(),
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
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final profileCubit = context.read<ProfileCubit>();
    final confirmed = await showConfirmSheet(
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
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.changeRoleConfirmTitle,
      body: l10n.changeRoleConfirmBody,
      action: l10n.actionConfirmChangeRole,
    );
    if (confirmed) await profileCubit.reset();
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

/// Region of the map: drawn on the device, so it is always offline.
class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final MapRegion region;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = region.assigned
        ? l10n.regionAssigned(region.name)
        : region.name;
    return AppCard(
      tone: AppCardTone.success,
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
            child: const Icon(Icons.map_outlined, color: AppColors.emerald),
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
                  l10n.regionOffline,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      onSelectionChanged: (selection) {
        context.read<LocaleCubit>().change(Locale(selection.first));
        // Shown in the new language, once it applies (6.4.4: "Configuración
        // guardada").
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
          );
        });
      },
    );
  }
}

/// Communication channels of A_06 / A_09 (6.4.4): what can sync now, and
/// what happens without signal.
class _ChannelsCard extends StatelessWidget {
  const _ChannelsCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final mesh = context.watch<MeshCubit>().state;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SyncChannels(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.channelsHint,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (mesh.supported) ...[
            const SizedBox(height: AppSpacing.xs),
            // Plan D5: the user turns Mesh on; it asks for Bluetooth.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: mesh.enabled,
              title: Text(l10n.meshSwitch, style: textTheme.titleSmall),
              subtitle: Text(
                mesh.permissionDenied
                    ? l10n.meshPermissionDenied
                    : l10n.meshSwitchDetail,
                style: textTheme.bodySmall?.copyWith(
                  color: mesh.permissionDenied
                      ? AppColors.coral
                      : AppColors.textSecondary,
                ),
              ),
              onChanged: (on) async {
                final messenger = ScaffoldMessenger.of(context);
                final cubit = context.read<MeshCubit>();
                await cubit.setEnabled(on);
                if (cubit.state.enabled == on) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.settingsSaved)),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
