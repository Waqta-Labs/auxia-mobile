import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/connectivity/connectivity_monitor.dart';
import '../../../core/sync/sync_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../emergencymanagement/application/mesh_service.dart';
import '../../../emergencymanagement/interfaces/mesh_cubit.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Channels the app can use to sync (A_05, A_06, A_09): cellular and Wi-Fi
/// as the device detects them, Mesh as the user left it (plan D5), and
/// satellite, which a phone does not let an app use.
class SyncChannels extends StatelessWidget {
  const SyncChannels({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final channels = context.select(
      (SyncCubit cubit) => cubit.state.network.channels,
    );
    final mesh = context.watch<MeshCubit>().state;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        channels.contains(NetworkChannel.cellular)
            ? _ChannelChip.available(l10n.channelCellular)
            : _ChannelChip.unavailable(
                l10n.channelUnavailable(l10n.channelCellular),
              ),
        if (channels.contains(NetworkChannel.wifi))
          _ChannelChip.available(l10n.channelWifi),
        _meshChip(l10n, mesh),
        _ChannelChip.unavailable(l10n.channelSatelliteUnavailable),
      ],
    );
  }

  static _ChannelChip _meshChip(AppLocalizations l10n, MeshState mesh) {
    if (!mesh.supported) {
      return _ChannelChip.unavailable(l10n.channelMeshUnsupported);
    }
    if (!mesh.enabled) return _ChannelChip.unavailable(l10n.channelMeshOff);
    if (mesh.peers == 0) {
      return _ChannelChip(l10n.channelMeshSearching, AppColors.skyBlue);
    }
    return _ChannelChip.available(l10n.channelMeshPeers(mesh.peers));
  }
}

/// Channel pill: dark background and a colored dot, with the state always
/// written (color is never the only signal).
class _ChannelChip extends StatelessWidget {
  const _ChannelChip(this.label, this.dot);

  const _ChannelChip.available(String label) : this(label, AppColors.emerald);

  const _ChannelChip.unavailable(String label) : this(label, AppColors.coral);

  final String label;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceDeep,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Wraps instead of overflowing with large text.
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
