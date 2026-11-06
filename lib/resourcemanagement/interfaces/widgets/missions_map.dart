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

/// Simplified map of A_07: numbered markers by Urgency Score, the position
/// of the brigadist and the dashed route to the active mission.
class MissionsMap extends StatefulWidget {
  const MissionsMap({
    super.key,
    required this.missions,
    required this.activeMission,
    required this.myLocation,
    required this.tileUrlTemplate,
    required this.overlayLabel,
    this.tileProvider,
  });

  final List<Mission> missions;
  final Mission? activeMission;
  final GeoPoint? myLocation;

  /// Raster tiles; null hides them (tests).
  final String? tileUrlTemplate;
  final String overlayLabel;

  /// Offline-first provider; null uses the network provider.
  final TileProvider? tileProvider;

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
        backgroundColor: AppColors.surfaceDeep,
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          maxZoom: 16,
        ),
      );
    }
    return MapOptions(
      backgroundColor: AppColors.surfaceDeep,
      initialCenter: points.isEmpty ? _fallbackCenter : points.first,
      initialZoom: 14,
    );
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
            FlutterMap(
              mapController: _controller,
              options: _options,
              children: [
                if (widget.tileUrlTemplate != null)
                  TileLayer(
                    urlTemplate: widget.tileUrlTemplate,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.waqtalabs.auxia_mobile',
                    retinaMode: RetinaMode.isHighDensity(context),
                    tileProvider: widget.tileProvider,
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
                if (widget.tileUrlTemplate != null)
                  const RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                      TextSourceAttribution('© CARTO'),
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
