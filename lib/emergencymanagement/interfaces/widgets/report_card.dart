import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/interfaces/time_ago.dart';
import '../../../shared/interfaces/widgets/app_card.dart';
import '../../../shared/interfaces/widgets/status_chip.dart';
import '../../application/citizen_report_sync.dart';
import '../../domain/model/citizen_report.dart';
import 'sos_widgets.dart';

/// Label and tone of each status of a citizen report (report 6.2.2).
(String, StatusTone) reportStatusLabel(
  AppLocalizations l10n,
  CitizenReport report, {
  SendIssue? issue,
}) => switch (report.status) {
  // Still on the device after failed attempts (6.4.4: "Reintento de envío").
  CitizenReportStatus.saved when issue?.failed ?? false => (
    l10n.statusSendFailed,
    StatusTone.danger,
  ),
  CitizenReportStatus.saved when issue != null => (
    l10n.statusRetrying(issue.attempts),
    StatusTone.info,
  ),
  CitizenReportStatus.saved => (l10n.statusSaved, StatusTone.info),
  CitizenReportStatus.transmitting => (
    l10n.statusTransmitting,
    StatusTone.progress,
  ),
  // Received but not prioritized yet: still on its way (plan D2).
  CitizenReportStatus.received => (
    l10n.statusTransmitting,
    StatusTone.progress,
  ),
  CitizenReportStatus.prioritized => (
    report.score == null
        ? l10n.statusPrioritizedNoScore
        : l10n.statusPrioritized(report.score!.round().toString()),
    StatusTone.highlight,
  ),
  CitizenReportStatus.brigadeOnTheWay => (
    report.etaMinutes == null
        ? l10n.statusBrigadeNoEta
        : l10n.statusBrigade(report.etaMinutes!),
    StatusTone.success,
  ),
};

/// Card of one report in the local queue (A_05): code, category, age,
/// status and the four steps Guardado → Transmitiendo → Priorizado por IA →
/// Brigada en camino.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    required this.now,
    this.issue,
    this.onTap,
  });

  final CitizenReport report;
  final DateTime now;

  /// Failed attempts to send it, if any.
  final SendIssue? issue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (label, tone) = reportStatusLabel(l10n, report, issue: issue);
    final barColor = switch (report.status) {
      CitizenReportStatus.prioritized => AppColors.lime,
      CitizenReportStatus.brigadeOnTheWay => AppColors.emerald,
      _ => AppColors.skyBlue,
    };
    final steps = report.status.completedSteps;

    return AppCard(
      tone: report.status == CitizenReportStatus.prioritized
          ? AppCardTone.selected
          : AppCardTone.normal,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.reportTitle(
                    report.code,
                    categoryLabel(l10n, report.category),
                  ),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                timeAgo(l10n, report.reportedAt, now),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          StatusChip(label: label, tone: tone),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: l10n.reportProgress(steps),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < steps ? barColor : AppColors.track,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the detail of a report (6.1.2: cards with details in a
/// bottom sheet).
class ReportDetailSheet extends StatelessWidget {
  const ReportDetailSheet({super.key, required this.report});

  final CitizenReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final detail = report.detail;
    final (label, tone) = reportStatusLabel(l10n, report);
    final conditions = {
      AccessCondition.roadBlocked: l10n.accessRoadBlocked,
      AccessCondition.noDrinkingWater: l10n.accessNoDrinkingWater,
      AccessCondition.noCellSignal: l10n.accessNoCellSignal,
      AccessCondition.damagedBuilding: l10n.accessDamagedBuilding,
    };
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportTitle(
                report.code,
                categoryLabel(l10n, report.category),
              ),
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            StatusChip(label: label, tone: tone),
            const SizedBox(height: AppSpacing.md),
            Text(
              report.location?.format() ?? l10n.reportNoLocation,
              style: muted,
            ),
            for (final (count, name) in [
              (detail.children, l10n.detailChildren),
              (detail.elderly, l10n.detailElderly),
              (detail.injured, l10n.detailInjured),
            ])
              if (count > 0)
                Text(
                  l10n.reportPeople(name, count),
                  style: textTheme.bodyMedium,
                ),
            for (final condition in AccessCondition.values)
              if (detail.accessConditions.contains(condition))
                Text(conditions[condition]!, style: textTheme.bodyMedium),
            if (detail.audioPath != null || detail.photoPath != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.reportEvidenceSaved, style: muted),
            ],
          ],
        ),
      ),
    );
  }
}
