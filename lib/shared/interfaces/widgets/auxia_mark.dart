import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// AuxIA isotype (report 6.1.1 Branding): the assistant's head with its
/// antenna and the open mouth that calls for help.
///
/// It is drawn from the same geometry as the brand SVG of the landing page,
/// so the app does not need an image asset to show the logo offline.
class AuxiaMark extends StatelessWidget {
  const AuxiaMark({
    super.key,
    this.size = 40,
    this.headColor = AppColors.white,
    this.featureColor = AppColors.background,
    this.accentColor = AppColors.lime,
    this.semanticLabel = 'AuxIA',
  });

  final double size;
  final Color headColor;
  final Color featureColor;
  final Color accentColor;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _AuxiaMarkPainter(
          headColor: headColor,
          featureColor: featureColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

class _AuxiaMarkPainter extends CustomPainter {
  _AuxiaMarkPainter({
    required this.headColor,
    required this.featureColor,
    required this.accentColor,
  });

  final Color headColor;
  final Color featureColor;
  final Color accentColor;

  // Coordinates come from the 48 x 48 brand SVG; the drawing spans from 4 to
  // 38 on both axes, so that square is mapped onto the widget.
  static const double _viewBox = 34;
  static const double _offset = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-_offset, -_offset);

    final head = Paint()..color = headColor;
    final feature = Paint()..color = featureColor;
    final accent = Paint()..color = accentColor;
    final antenna = Paint()
      ..color = featureColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawCircle(const Offset(20, 20), 15, head)
      ..drawLine(const Offset(10, 10), const Offset(22, 22), antenna)
      ..drawCircle(const Offset(10, 10), 4, feature)
      ..drawCircle(const Offset(28, 29), 10, feature)
      ..drawCircle(const Offset(29.5, 22), 3.5, head)
      ..drawCircle(const Offset(23.5, 29.5), 3.2, head)
      ..drawCircle(const Offset(33, 33), 4, accent)
      ..restore();
  }

  @override
  bool shouldRepaint(_AuxiaMarkPainter oldDelegate) =>
      oldDelegate.headColor != headColor ||
      oldDelegate.featureColor != featureColor ||
      oldDelegate.accentColor != accentColor;
}
