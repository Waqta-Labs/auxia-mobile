import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'auxia_mark.dart';

/// Top bar of the home screens (A_03 and A_07): the isotype on the left and
/// a role or brigade badge on the right.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AuxiaMark(),
        const SizedBox(width: AppSpacing.md),
        const Spacer(),
        if (trailing != null)
          Flexible(
            flex: 4,
            // On the right edge, as in the mockups of A_03 and A_07.
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
      ],
    );
  }
}
