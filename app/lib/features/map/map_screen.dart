import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/tile_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../location/location_controller.dart';
import '../location/location_service.dart';
import 'base_tile_layer.dart';
import 'map_attribution.dart';
import 'map_banner.dart';
import 'map_constants.dart';

/// S2 map screen (SPEC-001 §3): full-screen map, blue dot + accuracy circle,
/// "My location" FAB, one banner at the top (US-1.1).
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.tileConfig,
    required this.session,
    this.styleLoader = loadStyleFromNetwork,
    this.locationService,
    this.requestPermissionOnStart = false,
    this.onReopenConsent,
    this.onSearchCentreChanged,
    this.onAdjustRequested,
    this.mapController,
    this.clock,
    this.timerFactory,
  });

  final TileConfig tileConfig;
  final StyleLoader styleLoader;
  final MapSession session;

  /// `null` when location consent is not granted (BR-9, D3): then no
  /// location API is called and `banner_location_needed` reopens S1.
  final LocationService? locationService;

  /// True right after "Allow" on S1 (US-1.4 AC3): show the OS prompt.
  final bool requestPermissionOnStart;

  /// "Enable" after a declined consent (US-1.1 AC3).
  final VoidCallback? onReopenConsent;

  /// BR-3 (a)/(b) search hook for US-1.2 (US-1.1 AC8).
  final SearchCentreCallback? onSearchCentreChanged;

  /// "Adjust" on `banner_no_fix` — TODO(US-1.3): start adjust mode.
  final VoidCallback? onAdjustRequested;

  /// Optional, for tests.
  final MapController? mapController;
  final DateTime Function()? clock;
  final TimerFactory? timerFactory;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _map = widget.mapController ?? MapController();
  late final LocationController _location;
  late final AppLifecycleListener _lifecycle;
  late final AnimationController _camera;
  final Tween<double> _latTween = Tween<double>();
  final Tween<double> _lngTween = Tween<double>();
  final Tween<double> _zoomTween = Tween<double>();
  late final Animation<double> _cameraCurve;

  bool _mapReady = false;
  ({LatLng centre, double? zoom})? _pendingMove;

  static const Duration cameraAnimationDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _camera = AnimationController(vsync: this, duration: cameraAnimationDuration)
      ..addListener(_onCameraTick);
    _cameraCurve = CurvedAnimation(parent: _camera, curve: Curves.easeInOut);
    _location = LocationController(
      service: widget.locationService,
      session: widget.session,
      moveCamera: _moveCamera,
      onSearchCentreChanged: widget.onSearchCentreChanged,
      onReopenConsent: widget.onReopenConsent,
      onShowUnblockGuide: _showUnblockGuide,
      onAdjustRequested: widget.onAdjustRequested,
      clock: widget.clock,
      timerFactory: widget.timerFactory,
    )..addListener(_onLocationChanged);
    // NFR-5: stop the stream in the background; re-check on return
    // (US-1.1 AC5/AC6).
    _lifecycle = AppLifecycleListener(
      onHide: _location.pause,
      onShow: () => unawaited(_location.resume()),
    );
    unawaited(
      _location.start(requestPermission: widget.requestPermissionOnStart),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _location
      ..removeListener(_onLocationChanged)
      ..dispose();
    _camera.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  void _showUnblockGuide() {
    if (mounted) unawaited(showWebUnblockGuide(context));
  }

  void _onMapReady() {
    _mapReady = true;
    final pending = _pendingMove;
    _pendingMove = null;
    if (pending != null) _moveCamera(pending.centre, pending.zoom);
  }

  /// Animated camera move (US-1.1 AC8 "animates back").
  void _moveCamera(LatLng centre, double? zoom) {
    if (!_mapReady) {
      _pendingMove = (centre: centre, zoom: zoom);
      return;
    }
    final start = _map.camera;
    _latTween
      ..begin = start.center.latitude
      ..end = centre.latitude;
    _lngTween
      ..begin = start.center.longitude
      ..end = centre.longitude;
    _zoomTween
      ..begin = start.zoom
      ..end = zoom ?? start.zoom;
    _camera.forward(from: 0);
  }

  void _onCameraTick() {
    if (!_mapReady || _latTween.begin == null) return;
    _map.move(
      LatLng(_latTween.evaluate(_cameraCurve), _lngTween.evaluate(_cameraCurve)),
      _zoomTween.evaluate(_cameraCurve),
    );
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    // AC7: panning by the user turns follow mode off.
    _camera.stop();
    _location.onUserGesture();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fix = _location.userFix;
    final bannerKind = _location.banner;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: MapConstants.defaultCentre,
              initialZoom: MapConstants.initialZoom,
              minZoom: MapConstants.minZoom,
              maxZoom: widget.tileConfig.maxZoom,
              onMapReady: _onMapReady,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              buildBaseTileLayer(
                widget.tileConfig,
                styleLoader: widget.styleLoader,
              ),
              if (fix != null) ...[
                // AC2: accuracy circle, radius = reported accuracy.
                CircleLayer(
                  key: const ValueKey('user-accuracy-circle'),
                  circles: [
                    CircleMarker(
                      point: fix.position,
                      radius: fix.accuracy,
                      useRadiusInMeter: true,
                      color: const Color(0x332196F3),
                      borderColor: const Color(0x802196F3),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: fix.position,
                      width: 22,
                      height: 22,
                      child: const _BlueDot(key: ValueKey('user-location-dot')),
                    ),
                  ],
                ),
              ],
              // SPEC-001 BR-13: attribution always visible, text from config.
              MapAttribution(
                key: const ValueKey('map-attribution'),
                text: widget.tileConfig.attribution,
              ),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (bannerKind != null)
                      buildLocationBanner(context, bannerKind, _location),
                    if (_location.showLocatingHint)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Chip(
                          key: const ValueKey('hint-locating'),
                          avatar: const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: Text(l10n.hint_locating),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // "My location" FAB above the attribution (BR-13: never covered).
          Positioned(
            right: 16,
            bottom: 48,
            child: SafeArea(
              child: FloatingActionButton(
                key: const ValueKey('fab-my-location'),
                tooltip: l10n.a11y_my_location,
                onPressed: _location.onMyLocation,
                child: Icon(
                  _location.followMode
                      ? Icons.my_location
                      : Icons.location_searching,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueDot extends StatelessWidget {
  const _BlueDot({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Color(0x55000000))],
      ),
    );
  }
}
