import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sync/sync_cubit.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/connectivity_badge.dart';
import '../../../../shared/interfaces/widgets/empty_state.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../../shared/interfaces/widgets/sync_channels.dart';
import '../../widgets/report_card.dart';
import 'my_reports_cubit.dart';

/// A_05 · Mis reportes: status and sync queue of the citizen's reports.
class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<MyReportsCubit, MyReportsState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () => _retry(context),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                  vertical: AppSpacing.md,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.reportsTitle,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                      const ConnectivityBadge(
                        style: ConnectivityBadgeStyle.signal,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ChannelsCard(onRetry: () => _retry(context)),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.reports.isEmpty && !state.loading)
                    EmptyState(
                      icon: Icons.inbox_outlined,
                      message: l10n.reportsEmpty,
                    )
                  else ...[
                    SectionLabel(l10n.reportsQueue(state.reports.length)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final report in state.reports) ...[
                      ReportCard(
                        report: report,
                        now: now,
                        issue: state.issues[report.id],
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => ReportDetailSheet(report: report),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// "Forzar reintento de sincronización".
  static Future<void> _retry(BuildContext context) async {
    final sync = context.read<SyncCubit>();
    final reports = context.read<MyReportsCubit>();
    await sync.retryAll();
    await reports.refreshStatuses();
  }
}

/// Channels of A_05 with "Forzar reintento de sincronización".
class _ChannelsCard extends StatelessWidget {
  const _ChannelsCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sync = context.watch<SyncCubit>().state;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l10n.reportsChannels),
          const SizedBox(height: AppSpacing.sm),
          const SyncChannels(),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: sync.running ? null : onRetry,
            style: OutlinedButton.styleFrom(
              textStyle: Theme.of(context).textTheme.titleSmall,
            ),
            child: Text(l10n.actionForceRetry, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
