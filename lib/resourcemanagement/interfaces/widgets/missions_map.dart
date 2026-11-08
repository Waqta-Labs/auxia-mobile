import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/domain/geo_point.dart';
import '../../domain/model/mission.dart';

/// Color of a mission marker by its Urgency Score, as in A_07.
Color scoreColor(double? score) {
  if (score == null) return AppColors.neutralFill;
  if (score >= 85) return AppColors.lime;
  if (score >= 65) return AppColors.skyBlue;
  return AppColors.royalBlue;
}

/// Color of the glow around a mission: coral for a critical Urgency Score,
/// the urgency color of the design system (6.2) and of the A_07 mockup;
/// otherwise the color of its marker.
Color glowColor(double? score) =>
    score != null && score >= 85 ? AppColors.coral : scoreColor(score);

/// Stylized map of A_07, as in the mockup: a dark grid with a glow by
/// Urgency Score around each mission, numbered markers, the position of the
/// brigadist and the dashed route to the active mission.
///
/// It is drawn on the device from the coordinates of the missions, with no
/// map tile server, so it works the same without signal.
class MissionsMap extends StatefulWidget {
  const MissionsMap({
    super.key,
    required this.missions,
    required this.activeMission,
    required this.myLocation,
    required this.overlayLabel,
  });

  final List<Mission> missions;
  final Mission? activeMission;
  final GeoPoint? myLocation;
  final String overlayLabel;

  @override
  State<MissionsMap> createState() => _MissionsMapState();
}

class _MissionsMapState extends State<MissionsMap> {
  final MapController _controller = MapController();

  /// Lima, where the report locates the user personas, when nothing else is
  /// known.
  static const LatLng _fallbackCenter = LatLng(-12.0464, -77.0428);

  List<LatLng> get _points => [
    for (final mission in widget.missions)
      if (mission.location != null) _latLng(mission.location!),
    if (widget.myLocation != null) _latLng(widget.myLocation!),
  ];

  static LatLng _latLng(GeoPoint point) =>
      LatLng(point.latitude, point.longitude);

  MapOptions get _options {
    final points = _points;
    if (points.length >= 2) {
      return MapOptions(
        backgroundColor: Colors.transparent,
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          maxZoom: 16,
        ),
      );
    }
    return MapOptions(
      backgroundColor: Colors.transparent,
      initialCenter: points.isEmpty ? _fallbackCenter : points.first,
      initialZoom: 14,
    );
  }

  /// What the camera frames: the missions and whether the position is
  /// known. Moving with the GPS does not reframe the map.
  static Object _framing(MissionsMap map) => (
    [
      for (final mission in map.missions)
        if (mission.location != null) (mission.id, mission.location),
    ].toString(),
    map.myLocation != null,
  );

  @override
  void didUpdateWidget(MissionsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The map opens before the missions or the position arrive: frame them
    // when they do.
    if (_framing(oldWidget) != _framing(widget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recenter();
      });
    }
  }

  void _recenter() {
    final points = _points;
    if (points.length >= 2) {
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          maxZoom: 16,
        ),
      );
    } else if (points.isNotEmpty) {
      _controller.move(points.first, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = widget.activeMission?.location;
    final me = widget.myLocation;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: ColoredBox(
        color: AppColors.surfaceDeep,
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            FlutterMap(
              mapController: _controller,
              options: _options,
              children: [
                MarkerLayer(
                  markers: [
                    for (final mission in widget.missions)
                      if (mission.location != null)
                        Marker(
                          point: _latLng(mission.location!),
                          width: _glowSize,
                          height: _glowSize,
                          child: _Glow(color: glowColor(mission.score)),
                        ),
                  ],
                ),
                if (active != null && me != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_latLng(me), _latLng(active)],
                        color: AppColors.lime,
                        strokeWidth: 4,
                        pattern: StrokePattern.dashed(segments: const [12, 8]),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final mission in widget.missions)
                      if (mission.location != null)
                        Marker(
                          point: _latLng(mission.location!),
                          width: 48,
                          height: 48,
                          child: _ScoreMarker(
                            mission: mission,
                            label: l10n.mapMissionMarker(
                              mission.zoneName,
                              mission.score?.round().toString() ?? '—',
                            ),
                          ),
                        ),
                    if (me != null)
                      Marker(
                        point: _latLng(me),
                        width: 24,
                        height: 24,
                        child: Semantics(
                          label: l10n.mapMyLocation,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.skyBlue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.white,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: _Overlay(label: widget.overlayLabel),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: IconButton(
                onPressed: _recenter,
                tooltip: l10n.mapRecenter,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  fixedSize: const Size.square(AppSpacing.xxxl),
                ),
                icon: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diameter of the glow around a mission.
const double _glowSize = 180;

/// Soft halo of the color of the score, under the marker.
class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
    );
  }
}

/// Grid of the dark map of the mockup.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  static const double _cell = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var x = _cell; x < size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = _cell; y < size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _ScoreMarker extends StatelessWidget {
  const _ScoreMarker({required this.mission, required this.label});

  final Mission mission;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(mission.score);
    final dark = color == AppColors.lime || color == AppColors.skyBlue;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceDeep, width: 3),
        ),
        alignment: Alignment.center,
        child: Text(
          mission.score?.round().toString() ?? '—',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: dark ? AppColors.onAccent : AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
