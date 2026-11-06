import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/domain/geo_point.dart';
import '../../../shared/interfaces/time_ago.dart';
import '../../../shared/interfaces/widgets/app_card.dart';
import '../../../shared/interfaces/widgets/status_chip.dart';
import '../../domain/model/mission.dart';
import 'missions_map.dart';

/// "Por qué esta prioridad": the largest contributions to the Urgency Score
/// written in plain words (US-05, explainable AI).
String priorityExplanation(AppLocalizations l10n, Mission mission) {
  final parts = <String>[];
  final reasons = [...mission.reasons]
    ..sort((a, b) => b.points.compareTo(a.points));
  for (final reason in reasons) {
    final text = switch (reason.feature) {
      ScoreFeature.damageLevel => switch (mission.damage) {
        DamageLevel.low => l10n.damageLow,
        DamageLevel.moderate => l10n.damageModerate,
        DamageLevel.severe => l10n.damageSevere,
        DamageLevel.critical => l10n.damageCritical,
        null => null,
      },
      ScoreFeature.peopleAffected =>
        mission.people.peopleAffected > 0
            ? l10n.reasonPeopleAffected(mission.people.peopleAffected)
            : null,
      ScoreFeature.vulnerablePopulation => _vulnerable(l10n, mission.people),
      ScoreFeature.needs => l10n.reasonNeeds,
      ScoreFeature.other => null,
    };
    if (text != null && text.isNotEmpty) parts.add(text);
  }
  if (parts.isEmpty) return l10n.missionNoExplanation;
  final sentence = [
    for (final part in parts) '${part[0].toLowerCase()}${part.substring(1)}',
  ].join(', ');
  return '${sentence[0].toUpperCase()}${sentence.substring(1)}';
}

String _vulnerable(AppLocalizations l10n, ZonePeople people) => [
  if (people.children > 0) l10n.pillChildren(people.children),
  if (people.elderly > 0) l10n.pillElderly(people.elderly),
  if (people.disabled > 0) l10n.pillDisabled(people.disabled),
].join(', ');

String priorityLabel(AppLocalizations l10n, PriorityLevel level) =>
    switch (level) {
      PriorityLevel.low => l10n.priorityLow,
      PriorityLevel.medium => l10n.priorityMedium,
      PriorityLevel.high => l10n.priorityHigh,
      PriorityLevel.critical => l10n.priorityCritical,
    };

String unitLabel(AppLocalizations l10n, String? unit) => switch (unit) {
  'KG' => l10n.unitKg,
  'LITER' => l10n.unitLiter,
  'KIT' => l10n.unitKit,
  _ => l10n.unitUnit,
};

/// Mission card of A_07.
class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.myLocation,
    required this.now,
    required this.onStartNavigation,
    required this.onVerifyDelivery,
  });

  final Mission mission;
  final GeoPoint? myLocation;
  final DateTime now;
  final VoidCallback onStartNavigation;
  final VoidCallback onVerifyDelivery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    final location = mission.location;
    final distance = location != null && myLocation != null
        ? myLocation!.distanceKmTo(location)
        : null;
    final people = mission.people;

    return AppCard(
      tone: mission.status == MissionStatus.navigating
          ? AppCardTone.selected
          : AppCardTone.normal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scoreColor(mission.score),
                child: Text(
                  mission.score?.round().toString() ?? '—',
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.onAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission.zoneName, style: textTheme.titleLarge),
                    if (mission.assignedAt != null)
                      Text(
                        l10n.missionApprovedAgo(
                          timeAgo(l10n, mission.assignedAt!, now),
                        ),
                        style: muted,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusChip(
                label: priorityLabel(l10n, mission.priority),
                tone: StatusTone.info,
                showDot: false,
              ),
              if (mission.status == MissionStatus.navigating)
                StatusChip(
                  label: l10n.missionNavigating,
                  tone: StatusTone.highlight,
                ),
              if (mission.status == MissionStatus.completed)
                StatusChip(
                  label: l10n.missionCompleted,
                  tone: StatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            tone: AppCardTone.deep,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.missionWhyPriority.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.skyBlue,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    priorityExplanation(l10n, mission),
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          if (people.children + people.elderly + people.disabled > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (people.children > 0)
                  _Pill(l10n.pillChildren(people.children)),
                if (people.elderly > 0) _Pill(l10n.pillElderly(people.elderly)),
                if (people.disabled > 0)
                  _Pill(l10n.pillDisabled(people.disabled)),
              ],
            ),
          ],
          if (mission.items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.missionItems.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(color: AppColors.skyBlue),
            ),
            for (final item in mission.items)
              Text(
                l10n.missionItem(
                  item.quantity,
                  unitLabel(l10n, item.unit),
                  item.name,
                ),
                style: textTheme.bodyMedium,
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (distance != null)
                Text(
                  l10n.missionDistance(
                    distance.toStringAsFixed(1),
                    estimatedMinutes(distance),
                  ),
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.skyBlue,
                  ),
                ),
              if (location != null)
                Text(l10n.missionGps(location.format()), style: muted),
            ],
          ),
          if (mission.isOpen) ...[
            const SizedBox(height: AppSpacing.md),
            if (mission.status == MissionStatus.navigating) ...[
              FilledButton(
                onPressed: onVerifyDelivery,
                child: Text(l10n.actionVerifyDelivery),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                onPressed: onStartNavigation,
                child: Text(l10n.actionOpenNavigation),
              ),
            ] else
              FilledButton(
                onPressed: onStartNavigation,
                child: Text(l10n.actionStartNavigation),
              ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.outline),
        color: AppColors.surfaceHigh,
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
