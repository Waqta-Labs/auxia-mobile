import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/connectivity/connectivity_monitor.dart';
import '../../../core/sync/sync_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Channels the app can use to sync (A_05, A_06, A_09). The device detects
/// cellular and Wi-Fi; Mesh and Satellite are shown as unavailable on this
/// device (TS-C08, see the project guide).
class SyncChannels extends StatelessWidget {
  const SyncChannels({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final channels = context.select(
      (SyncCubit cubit) => cubit.state.network.channels,
    );
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _ChannelChip(
          name: l10n.channelCellular,
          available: channels.contains(NetworkChannel.cellular),
        ),
        if (channels.contains(NetworkChannel.wifi))
          _ChannelChip(name: l10n.channelWifi, available: true),
        _ChannelChip(name: l10n.channelMesh, available: false),
        _ChannelChip(name: l10n.channelSatellite, available: false),
      ],
    );
  }
}

/// Channel pill: dark background, emerald dot when the channel can sync, and
/// coral dot with "no disponible" written when it cannot (color is never the
/// only signal).
class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.name, required this.available});

  final String name;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = available ? name : l10n.channelUnavailable(name);
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
              decoration: BoxDecoration(
                color: available ? AppColors.emerald : AppColors.coral,
                shape: BoxShape.circle,
              ),
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
