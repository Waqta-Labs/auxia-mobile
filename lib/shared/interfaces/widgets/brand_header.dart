import 'package:flutter/material.dart';

import 'auxia_mark.dart';

/// Top bar of the home screens (A_03 and A_07): the isotype on the left and
/// a role or brigade badge on the right.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [const AuxiaMark(), const Spacer(), ?trailing]);
  }
}
