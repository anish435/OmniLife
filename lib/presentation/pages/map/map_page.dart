import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_semantic_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../../domain/entities/saved_location.dart';
import '../../controllers/places_controller.dart';
import '../../widgets/access_state_card.dart';
import '../../widgets/app_empty_view.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading_view.dart';
import '../../widgets/places/save_place_sheet.dart';

/// Map of saved places over OpenStreetMap tiles.
///
/// Tap or long-press the map to save a place there. Location permission is
/// only requested from the "Use my location" actions.
class MapPage extends StatefulWidget {
  const MapPage({super.key, this.tileProvider});

  /// Override in tests to avoid network tile requests.
  final TileProvider? tileProvider;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final PlacesController _c = Get.find<PlacesController>();
  final MapController _map = MapController();
  Worker? _noticeWorker;
  bool _centeredOnce = false;

  static const _worldCenter = LatLng(20, 0);

  @override
  void initState() {
    super.initState();
    _noticeWorker = ever<String?>(_c.notice, (msg) {
      if (msg == null || !mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      _c.notice.value = null;
    });
  }

  @override
  void dispose() {
    _noticeWorker?.dispose();
    _map.dispose();
    super.dispose();
  }

  LatLng _initialCenter() {
    final p = _c.position.value;
    if (p != null) return LatLng(p.latitude, p.longitude);
    if (_c.locations.isNotEmpty) {
      final l = _c.locations.first;
      return LatLng(l.latitude, l.longitude);
    }
    return _worldCenter;
  }

  double _initialZoom() =>
      (_c.position.value != null || _c.locations.isNotEmpty) ? 14 : 2;

  Future<void> _locate() async {
    await _c.enableLocation();
    _moveToPosition();
  }

  void _moveToPosition() {
    final p = _c.position.value;
    if (p == null) return;
    try {
      _map.move(LatLng(p.latitude, p.longitude), 16);
    } catch (_) {
      // Map not laid out yet.
    }
  }

  Future<void> _savePlaceAt(LatLng point, {SavedLocation? existing}) async {
    final result = await showModalBottomSheet<SavePlaceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavePlaceSheet(
        latitude: existing?.latitude ?? point.latitude,
        longitude: existing?.longitude ?? point.longitude,
        existing: existing,
        linkOptions: _c.linkOptions,
      ),
    );
    if (result == null) return;
    if (existing == null) {
      await _c.saveLocation(
        name: result.name,
        latitude: point.latitude,
        longitude: point.longitude,
        radiusMeters: result.radiusMeters,
        linkedTaskId: result.linkedTaskId,
        linkedEventId: result.linkedEventId,
      );
    } else if (result.delete) {
      await _c.deleteLocation(existing);
    } else {
      await _c.updateLocation(
        existing,
        name: result.name,
        radiusMeters: result.radiusMeters,
        clearLinks: true,
        linkedTaskId: result.linkedTaskId,
        linkedEventId: result.linkedEventId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Obx(() {
        if (_c.isLoading.value) {
          return const AppLoadingView(message: 'Loading your places');
        }
        if (_c.loadError.value != null) {
          return AppErrorView(message: _c.loadError.value!, onRetry: _c.load);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final map = _buildMap(context);
            final panel = _buildPanel(context);
            if (wide) {
              return Row(
                children: [
                  Expanded(flex: 3, child: map),
                  SizedBox(width: 380, child: panel),
                ],
              );
            }
            return Column(
              children: [
                Expanded(flex: 5, child: map),
                Expanded(flex: 5, child: panel),
              ],
            );
          },
        );
      }),
    );
  }

  Widget _buildMap(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Obx(() {
          final pos = _c.position.value;
          final places = _c.locations.toList();
          final inside = _c.insideIds.toSet();
          if (pos != null && !_centeredOnce) {
            _centeredOnce = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _moveToPosition(),
            );
          }
          return FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _initialCenter(),
              initialZoom: _initialZoom(),
              minZoom: 2,
              maxZoom: 19,
              onTap: (_, point) => _savePlaceAt(point),
              onLongPress: (_, point) => _savePlaceAt(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.omnilife.omnilife',
                tileProvider: widget.tileProvider,
                maxNativeZoom: 19,
              ),
              CircleLayer(
                circles: [
                  for (final l in places)
                    CircleMarker(
                      point: LatLng(l.latitude, l.longitude),
                      radius: l.radiusMeters,
                      useRadiusInMeter: true,
                      color: theme.colorScheme.primary.withValues(
                        alpha: inside.contains(l.id) ? 0.25 : 0.12,
                      ),
                      borderColor: theme.colorScheme.primary,
                      borderStrokeWidth: 1.5,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final l in places)
                    Marker(
                      point: LatLng(l.latitude, l.longitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _savePlaceAt(
                          LatLng(l.latitude, l.longitude),
                          existing: l,
                        ),
                        child: Icon(
                          Icons.place,
                          size: 34,
                          color: theme.colorScheme.primary,
                          semanticLabel: l.name,
                        ),
                      ),
                    ),
                  if (pos != null)
                    Marker(
                      point: LatLng(pos.latitude, pos.longitude),
                      width: 22,
                      height: 22,
                      child: Container(
                        key: const Key('current_location_marker'),
                        decoration: BoxDecoration(
                          color: context.semanticColors.info,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
              // OSM tile usage policy: attribution must stay visible.
              Align(
                alignment: Alignment.bottomLeft,
                child: IgnorePointer(
                  child: Container(
                    key: const Key('osm_attribution'),
                    margin: const EdgeInsets.all(AppSpacing.xs),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        Positioned(
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          child: Material(
            color: theme.colorScheme.surface,
            shape: const CircleBorder(),
            elevation: 0,
            child: IconButton(
              key: const Key('locate_me_button'),
              tooltip: 'Use my location',
              icon: const Icon(Icons.my_location),
              onPressed: _locate,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Obx(() {
        final access = _c.access.value;
        final places = _c.locations.toList();
        final next = _c.nextPlace;
        final inside = _c.insideIds.toSet();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _accessSection(context, access),
            if (access == LocationAccess.granted && next != null) ...[
              _nextPlaceSummary(context, next),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (access == LocationAccess.granted && places.isNotEmpty)
              SwitchListTile(
                key: const Key('geofence_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Arrival and departure alerts'),
                subtitle: const Text(
                  'Works while OmniLife is open. Background alerts are not '
                  'supported yet.',
                ),
                value: _c.geofenceEnabled.value,
                onChanged: _c.setGeofencing,
              ),
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                'SAVED PLACES',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.8,
                  color: context.semanticColors.mutedText,
                ),
              ),
            ),
            if (places.isEmpty)
              const AppEmptyView(
                icon: Icons.place_outlined,
                message: 'No saved places yet',
                subtitle: 'Tap or long-press the map to save one.',
              )
            else
              for (final l in places)
                _placeRow(context, l, inside.contains(l.id)),
          ],
        );
      }),
    );
  }

  Widget _accessSection(BuildContext context, LocationAccess? access) {
    switch (access) {
      case null:
      case LocationAccess.granted:
        return const SizedBox.shrink();
      case LocationAccess.denied:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AccessStateCard(
            icon: Icons.location_searching,
            title: 'Show where you are',
            message:
                'Allow location to see your position and distances to your '
                'saved places. You can still save places without it.',
            primaryLabel: 'Use my location',
            onPrimary: _locate,
            busy: _c.isLocating.value,
          ),
        );
      case LocationAccess.deniedForever:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AccessStateCard(
            icon: Icons.location_off_outlined,
            title: 'Location access is off',
            message:
                'Location was blocked for OmniLife. Turn it on in settings to '
                'see your position. Saving places still works.',
            primaryLabel: 'Open settings',
            onPrimary: () async {
              await _c.openSettings();
            },
            secondaryLabel: 'Check again',
            onSecondary: _c.recheckAccess,
          ),
        );
      case LocationAccess.serviceDisabled:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AccessStateCard(
            icon: Icons.location_disabled_outlined,
            title: 'Location is switched off',
            message:
                'Turn on location for this device to see your position. '
                'Saving places still works.',
            primaryLabel: 'Open settings',
            onPrimary: () async {
              await _c.openSettings();
            },
            secondaryLabel: 'Check again',
            onSecondary: _c.recheckAccess,
          ),
        );
      case LocationAccess.unsupported:
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: AccessStateCard(
            icon: Icons.info_outline,
            title: 'Location is not available here',
            message:
                'This device or browser cannot share its location. You can '
                'still browse the map and save places.',
          ),
        );
    }
  }

  Widget _nextPlaceSummary(BuildContext context, SavedLocation next) {
    final theme = Theme.of(context);
    final label = _c.distanceLabelTo(next);
    return Container(
      key: const Key('next_place_summary'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.near_me_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nearest place', style: theme.textTheme.labelSmall),
                Text(
                  next.name,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (label != null)
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeRow(BuildContext context, SavedLocation l, bool inside) {
    final theme = Theme.of(context);
    final distance = _c.distanceLabelTo(l);
    final link = l.linkedTaskId != null
        ? 'Linked to a task'
        : l.linkedEventId != null
        ? 'Linked to an event'
        : null;
    return InkWell(
      onTap: () => _savePlaceAt(LatLng(l.latitude, l.longitude), existing: l),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                inside ? Icons.place : Icons.place_outlined,
                color: inside
                    ? theme.colorScheme.primary
                    : context.semanticColors.mutedText,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      [
                        'Radius ${formatDistance(l.radiusMeters)}',
                        ?link,
                        if (inside) 'You are here',
                      ].join('  -  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.semanticColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (distance != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    distance,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
