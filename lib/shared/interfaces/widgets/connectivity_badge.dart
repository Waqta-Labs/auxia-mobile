import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/sync/sync_cubit.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'status_chip.dart';

/// Which message the badge gives (report 6.1.2 C, Badge de Conectividad).
enum ConnectivityBadgeStyle {
  /// "Modo Offline Activo" in emerald: the app keeps working and saves on
  /// the device (A_03, A_06, A_09).
  mode,

  /// "Sin señal" in coral: no channel can sync right now (A_05).
  signal,
}

/// Discreet connectivity indicator shown at the top of the screens.
class ConnectivityBadge extends StatelessWidget {
  const ConnectivityBadge({
    super.key,
    this.style = ConnectivityBadgeStyle.mode,
  });

  final ConnectivityBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = context.select(
      (SyncCubit cubit) => cubit.state.network.isOnline,
    );

    final (label, tone) = switch ((style, online)) {
      (ConnectivityBadgeStyle.mode, false) => (
        l10n.connectionOfflineMode,
        StatusTone.success,
      ),
      (ConnectivityBadgeStyle.mode, true) => (
        l10n.connectionOnline,
        StatusTone.info,
      ),
      (ConnectivityBadgeStyle.signal, false) => (
        l10n.connectionNoSignal,
        StatusTone.danger,
      ),
      (ConnectivityBadgeStyle.signal, true) => (
        l10n.connectionWithSignal,
        StatusTone.success,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: StatusChip(label: label, tone: tone),
    );
  }
}

/// Thin progress bar shown while queued data syncs (report 6.1.2 C,
/// Feedback de Sincronización).
class SyncProgressBar extends StatelessWidget {
  const SyncProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (SyncCubit cubit) => (cubit.state.running, cubit.state.progress),
    );
    if (!state.$1) return const SizedBox(height: 3);
    return Semantics(
      label: AppLocalizations.of(context).syncInProgress,
      child: LinearProgressIndicator(minHeight: 3, value: state.$2),
    );
  }
}
