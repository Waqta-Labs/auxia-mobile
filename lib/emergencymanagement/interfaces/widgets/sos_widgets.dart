import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../domain/model/citizen_report.dart';

/// Localized label of each help category (report 6.2.2).
String categoryLabel(AppLocalizations l10n, HelpCategory category) =>
    switch (category) {
      HelpCategory.medical => l10n.categoryMedical,
      HelpCategory.rescue => l10n.categoryRescue,
      HelpCategory.supplies => l10n.categorySupplies,
    };

/// Giant one-tap SOS button with a visual pulse that guides the citizen in
/// moments of panic (6.4.3). The pulse stops when the system asks to reduce
/// motion.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _pulse
        ..stop()
        ..value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, 320.0);
        final core = size * 0.66;
        return SizedBox.square(
          dimension: size,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => CustomPaint(
              painter: _PulsePainter(progress: _pulse.value, core: core),
              child: child,
            ),
            child: Center(
              child: Semantics(
                button: true,
                label: widget.semanticLabel,
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: core,
                  child: Material(
                    color: AppColors.lime,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onPressed,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            child: Text(
                              l10n.sosButton,
                              style: AppTypography.sos.copyWith(
                                fontSize: core * 0.36,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.sosOneTap.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.onAccent,
                                  letterSpacing: 2,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.core});

  final double progress;
  final double core;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2 - 2;
    final minRadius = core / 2;
    for (final offset in const [0.0, 0.5]) {
      final t = (progress + offset) % 1;
      final radius = minRadius + (maxRadius - minRadius) * (0.35 + 0.65 * t);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.lime.withValues(alpha: 0.9 * (1 - t) + 0.1);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.core != core;
}

/// The three help categories as large toggle buttons.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final HelpCategory selected;
  final ValueChanged<HelpCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        for (final category in HelpCategory.values) ...[
          if (category != HelpCategory.values.first)
            const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _CategoryButton(
              label: categoryLabel(l10n, category),
              selected: category == selected,
              onTap: () => onSelected(category),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      side: BorderSide(
        color: selected ? AppColors.skyBlue : AppColors.outline,
        width: selected ? 2 : 1,
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.royalBlue : AppColors.neutralFill,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
