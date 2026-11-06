import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Screen layout with a scrollable body and the main actions pinned to the
/// bottom third, in the thumb zone (report 6.1.2 A).
class BottomActionLayout extends StatelessWidget {
  const BottomActionLayout({
    super.key,
    required this.body,
    required this.actions,
  });

  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              child: body,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.xs,
              AppSpacing.screen,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  actions[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
