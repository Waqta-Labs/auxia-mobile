import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/bottom_action_area.dart';
import '../../../../shared/interfaces/widgets/screen_header.dart';
import '../../../../shared/interfaces/widgets/section_label.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';
import '../../../domain/model/citizen_report.dart';
import 'emergency_detail_cubit.dart';

/// A_04 · Detalle de emergencia, optional after the SOS.
class EmergencyDetailScreen extends StatelessWidget {
  const EmergencyDetailScreen({
    super.key,
    required this.reportCode,
    required this.onBack,
    required this.onSent,
  });

  /// Code of the SOS just saved, such as SR-0412.
  final String reportCode;

  final VoidCallback onBack;

  /// After "Guardar y Enviar Auxilio": opens Mis reportes (A_05).
  final VoidCallback onSent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<EmergencyDetailCubit, EmergencyDetailState>(
      listenWhen: (previous, current) =>
          (!previous.submitted && current.submitted) ||
          (!previous.failed && current.failed) ||
          (previous.evidenceIssue != current.evidenceIssue &&
              current.evidenceIssue != null),
      listener: (context, state) {
        if (state.submitted) {
          HapticFeedback.mediumImpact();
          onSent();
          return;
        }
        final message = switch (state.evidenceIssue) {
          EvidenceIssue.microphone => l10n.microphoneDenied,
          EvidenceIssue.camera => l10n.cameraError,
          null => l10n.errorUnexpected,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        body: BlocBuilder<EmergencyDetailCubit, EmergencyDetailState>(
          builder: (context, state) {
            final cubit = context.read<EmergencyDetailCubit>();
            return BottomActionLayout(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(
                    title: l10n.detailTitle,
                    onBack: onBack,
                    backTooltip: l10n.actionBack,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: StatusChip(
                      label: l10n.sosSavedChip(reportCode),
                      tone: StatusTone.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.detailIntro,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SectionLabel(l10n.detailWhoNeedsHelp),
                  const SizedBox(height: AppSpacing.sm),
                  for (final (group, label) in [
                    (PeopleGroup.children, l10n.detailChildren),
                    (PeopleGroup.elderly, l10n.detailElderly),
                    (PeopleGroup.injured, l10n.detailInjured),
                  ]) ...[
                    _CounterRow(
                      label: label,
                      value: state.count(group),
                      onDecrement: () => cubit.decrement(group),
                      onIncrement: () => cubit.increment(group),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SectionLabel(l10n.detailAccess),
                  const SizedBox(height: AppSpacing.sm),
                  _AccessGrid(
                    selected: state.detail.accessConditions,
                    onToggle: cubit.toggleCondition,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionLabel(l10n.detailEvidence),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _AudioTile(
                          recording: state.recording,
                          saved: state.detail.audioPath != null,
                          onStart: cubit.startAudio,
                          onStop: cubit.stopAudio,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _EvidenceTile(
                          icon: Icons.circle_outlined,
                          iconBackground: AppColors.royalBlue,
                          title: l10n.evidencePhoto,
                          hint: state.detail.photoPath != null
                              ? l10n.evidencePhotoSaved
                              : l10n.evidencePhotoHint,
                          done: state.detail.photoPath != null,
                          onTap: cubit.takePhoto,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: state.submitting ? null : cubit.submit,
                  child: Text(l10n.actionSaveAndSend),
                ),
                Text(
                  l10n.detailFootnote,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.titleMedium)),
          IconButton(
            onPressed: value > 0 ? onDecrement : null,
            tooltip: l10n.counterDecrease(label),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.neutralFill,
              disabledBackgroundColor: AppColors.track,
              foregroundColor: AppColors.textPrimary,
              fixedSize: const Size.square(AppSpacing.xxxl),
            ),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: AppSpacing.xxxl,
            child: Semantics(
              liveRegion: true,
              label: '$label: $value',
              excludeSemantics: true,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(color: AppColors.lime),
              ),
            ),
          ),
          IconButton(
            onPressed: value < EmergencyDetail.maxPeople ? onIncrement : null,
            tooltip: l10n.counterIncrease(label),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.onAccent,
              fixedSize: const Size.square(AppSpacing.xxxl),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _AccessGrid extends StatelessWidget {
  const _AccessGrid({required this.selected, required this.onToggle});

  final Set<AccessCondition> selected;
  final ValueChanged<AccessCondition> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      AccessCondition.roadBlocked: l10n.accessRoadBlocked,
      AccessCondition.noDrinkingWater: l10n.accessNoDrinkingWater,
      AccessCondition.noCellSignal: l10n.accessNoCellSignal,
      AccessCondition.damagedBuilding: l10n.accessDamagedBuilding,
    };
    const conditions = AccessCondition.values;
    return Column(
      children: [
        for (var row = 0; row < conditions.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.xs),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = row; i < row + 2; i++) ...[
                  if (i > row) const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _CheckTile(
                      label: labels[conditions[i]]!,
                      checked: selected.contains(conditions[i]),
                      onTap: () => onToggle(conditions[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: AppCard(
        tone: checked ? AppCardTone.selected : AppCardTone.normal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              color: checked ? AppColors.lime : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Audio · 5 s · Mantén para grabar", or tap to start and stop.
class _AudioTile extends StatelessWidget {
  const _AudioTile({
    required this.recording,
    required this.saved,
    required this.onStart,
    required this.onStop,
  });

  final bool recording;
  final bool saved;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.selectionClick();
        onStart();
      },
      onLongPressEnd: (_) => onStop(),
      child: _EvidenceTile(
        icon: recording ? Icons.stop : Icons.fiber_manual_record,
        iconBackground: AppColors.coral,
        title: l10n.evidenceAudio,
        hint: recording
            ? l10n.evidenceAudioRecording
            : saved
            ? l10n.evidenceAudioSaved
            : l10n.evidenceAudioHint,
        done: saved && !recording,
        active: recording,
        // Not everyone can hold (screen readers, motor impairments): a tap
        // starts, and another tap or the 5 s limit stops.
        onTap: recording ? onStop : onStart,
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.hint,
    required this.done,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final Color iconBackground;
  final String title;
  final String hint;
  final bool done;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      tone: active
          ? AppCardTone.info
          : done
          ? AppCardTone.success
          : AppCardTone.normal,
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: iconBackground,
            foregroundColor: AppColors.white,
            child: Icon(done ? Icons.check : icon),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(title, style: textTheme.titleSmall, textAlign: TextAlign.center),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
