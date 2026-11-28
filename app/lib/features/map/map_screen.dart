import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/tile_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../location/location_controller.dart';
import '../location/location_service.dart';
import '../lots/connectivity_monitor.dart';
import '../lots/lot_card.dart';
import '../lots/lot_clustering.dart';
import '../lots/lot_pins_layer.dart';
import '../lots/lot_placeholder_screen.dart';
import '../lots/lots_controller.dart';
import '../lots/lots_geo.dart';
import '../lots/lots_repository.dart';
import '../lots/parking_lot.dart';
import 'adjust_mode.dart';
import 'base_tile_layer.dart';
import 'map_attribution.dart';
import 'map_banner.dart';
import 'map_constants.dart';

/// S2 map screen (SPEC-001 §3): full-screen map, blue dot + accuracy circle,
/// "My location" FAB, one banner at the top (US-1.1), lot pins, clusters,
/// "Search this area" chip and the lot mini card (US-1.2), overflow menu,
/// adjust mode and the manual position marker (US-1.3).
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.tileConfig,
    required this.session,
    required this.lotsRepository,
    this.connectivity,
    this.styleLoader = loadStyleFromNetwork,
    this.locationService,
    this.requestPermissionOnStart = false,
    this.onReopenConsent,
    this.onSearchCentreChanged,
    this.mapController,
    this.clock,
    this.timerFactory,
  });

  final TileConfig tileConfig;
  final StyleLoader styleLoader;
  final MapSession session;

  /// `nearby_lots` source (US-1.2).
  final LotsRepository lotsRepository;

  /// Offline → online events for the single auto retry (US-1.2 AC5).
  final ConnectivityMonitor? connectivity;

  /// `null` when location consent is not granted (BR-9, D3): then no
  /// location API is called and `banner_location_needed` reopens S1.
  final LocationService? locationService;

  /// True right after "Allow" on S1 (US-1.4 AC3): show the OS prompt.
  final bool requestPermissionOnStart;

  /// "Enable" after a declined consent (US-1.1 AC3).
  final VoidCallback? onReopenConsent;

  /// Observer of the BR-3 (a)–(c) search triggers (tests). Lots are loaded
  /// by the screen's own lots controller.
  final SearchCentreCallback? onSearchCentreChanged;

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
  late final LotsController _lots;
  late final LocationController _location;
  late final AppLifecycleListener _lifecycle;
  late final AnimationController _camera;
  final Tween<double> _latTween = Tween<double>();
  final Tween<double> _lngTween = Tween<double>();
  final Tween<double> _zoomTween = Tween<double>();
  late final Animation<double> _cameraCurve;

  bool _mapReady = false;
  ({LatLng centre, double? zoom})? _pendingMove;

  /// AC7: key of the spiderfied cluster, or `null`.
  String? _spiderKey;
  List<ParkingLot> _shownLots = const [];

  static const Duration cameraAnimationDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _camera = AnimationController(vsync: this, duration: cameraAnimationDuration)
      ..addListener(_onCameraTick);
    _cameraCurve = CurvedAnimation(parent: _camera, curve: Curves.easeInOut);
    _lots = LotsController(
      repository: widget.lotsRepository,
      connectivity: widget.connectivity,
    )..addListener(_onLotsChanged);
    _location = LocationController(
      service: widget.locationService,
      session: widget.session,
      moveCamera: _moveCamera,
      // BR-3 (a)–(c) → US-1.2 AC1 (point already per BR-14).
      onSearchCentreChanged: (point, trigger) {
        widget.onSearchCentreChanged?.call(point, trigger);
        _lots.onSearchTrigger(point, trigger);
      },
      onReopenConsent: widget.onReopenConsent,
      onShowUnblockGuide: _showUnblockGuide,
      onUsingGps: _showUsingGpsToast,
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
    _lots
      ..removeListener(_onLotsChanged)
      ..dispose();
    _camera.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  void _onLotsChanged() {
    if (!mounted) return;
    // Camera events can arrive during layout (e.g. a resize): rebuild after
    // the frame instead of calling setState mid-build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _onLotsChanged());
      return;
    }
    setState(() {
      if (!identical(_shownLots, _lots.lots)) {
        _shownLots = _lots.lots;
        _spiderKey = null;
      }
    });
  }

  void _showUnblockGuide() {
    if (mounted) unawaited(showWebUnblockGuide(context));
  }

  /// US-1.3 AC4: toast `toast_using_gps` (floating, above the FAB and the
  /// attribution, BR-13).
  void _showUsingGpsToast() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('toast-using-gps'),
          content: Text(l10n.toast_using_gps),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        ),
      );
  }

  // ---------------------------------------------------------------- US-1.3

  /// AC2: "Set my position" in the overflow menu.
  void _onSetPosition() => _location.startAdjust();

  /// AC2: long-press starts adjust mode (or, in adjust mode, only moves) and
  /// animates the pressed point under the crosshair (Q-QA-17).
  void _onLongPress(TapPosition _, LatLng point) {
    _location
      ..startAdjust()
      ..onUserGesture(); // a user-initiated move (US-1.1 AC7/AC12)
    // Like a cluster tap: the "Search this area" chip may appear later.
    _lots.onUserZoom();
    _moveCamera(point, null);
  }

  /// AC3: the point under the crosshair (the map centre) becomes the manual
  /// position.
  void _onConfirmAdjust() {
    _camera.stop();
    _location.confirmAdjust(_map.camera.center);
  }

  void _onMapReady() {
    _mapReady = true;
    _lots.onCameraChanged(_map.camera, hasGesture: false);
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
    // AC6: only updates the "Search this area" chip, never loads.
    _lots.onCameraChanged(camera, hasGesture: hasGesture);
    if (_spiderKey != null &&
        (hasGesture || camera.zoom < widget.tileConfig.maxZoom - 0.01)) {
      _spiderKey = null;
      _onLotsChanged(); // frame-safe rebuild
    }
    if (!hasGesture) return;
    // AC7: panning by the user turns follow mode off.
    _camera.stop();
    _location.onUserGesture();
  }

  /// US-1.2 AC7: zoom in until the pins separate; at max zoom spiderfy.
  void _onClusterTap(LotCluster cluster, MapCamera camera) {
    final maxZoom = widget.tileConfig.maxZoom;
    if (camera.zoom >= maxZoom - 0.01) {
      setState(() => _spiderKey = cluster.key);
      return;
    }
    final target = LotClustering.zoomTarget(cluster, camera, maxZoom: maxZoom);
    // A user-initiated zoom: follow mode off; the chip may appear.
    _lots.onUserZoom();
    _location.onUserGesture();
    _moveCamera(target.centre, target.zoom);
  }

  void _onMapTap(TapPosition _, LatLng _) {
    _lots.select(null);
    if (_spiderKey != null) setState(() => _spiderKey = null);
  }

  /// AC8: card tap → `/lot/:id` (US-3.1 builds the real screen).
  void _openLot(ParkingLot lot) {
    unawaited(Navigator.of(context).pushNamed(
      LotPlaceholderScreen.routeFor(lot.id),
      arguments: lot,
    ));
  }

  /// SPEC-001 §3 single banner: `error_load` first, then the location
  /// banners in their own priority (US-1.1).
  MapBannerKind? get _bannerKind =>
      _lots.hasError ? MapBannerKind.loadError : _location.banner;

  /// BR-11: the user's position (manual, GPS fix or last-known — BR-8), or
  /// `null` when there is none (declined, denied/blocked, GPS off, timeout
  /// without last-known). The default centre is never a distance source
  /// (D7): the card then hides the distance.
  LatLng? get _userPosition => _location.userPosition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // US-1.3 AC3: a manual position replaces the blue dot.
    final fix = _location.blueDot;
    final manual = _location.manualPosition;
    final adjusting = _location.isAdjusting;
    final bannerKind = _bannerKind;
    // Adjust mode shows only the hint at the top and Confirm / Cancel at
    // the bottom (the card and FAB come back afterwards).
    final selected = adjusting ? null : _lots.selectedLot;

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
              onTap: _onMapTap,
              onLongPress: _onLongPress, // US-1.3 AC2
            ),
            children: [
              buildBaseTileLayer(
                widget.tileConfig,
                styleLoader: widget.styleLoader,
              ),
              if (fix != null)
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
              // US-1.2 AC2, AC7, AC8.
              LotPinsLayer(
                key: const ValueKey('lot-pins-layer'),
                lots: _lots.lots,
                selectedId: selected?.id,
                spiderfiedKey: _spiderKey,
                // Adjust mode: pins are not selectable (no card shown).
                onLotTap: adjusting ? (_) {} : _lots.select,
                onClusterTap: _onClusterTap,
              ),
              if (fix != null)
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
              if (manual != null)
                MarkerLayer(markers: [manualPositionMarker(context, manual)]),
              // SPEC-001 BR-13: attribution always visible, text from config.
              MapAttribution(
                key: const ValueKey('map-attribution'),
                text: widget.tileConfig.attribution,
              ),
            ],
          ),
          // US-1.3 AC2: crosshair fixed at the screen centre (= map centre).
          if (adjusting) const AdjustCrosshair(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: adjusting
                    ? const AdjustHint()
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTopColumn(l10n, bannerKind)),
                          const SizedBox(width: 8),
                          _OverflowMenu(onSetPosition: _onSetPosition),
                        ],
                      ),
              ),
            ),
          ),
          // US-1.2 AC8 mini card: bottom, left of the FAB and above the
          // attribution (BR-13: never covered).
          if (selected != null)
            Positioned(
              left: 8,
              right: 84,
              bottom: 48,
              child: SafeArea(
                // Wide screens (Web/tablet): keep the card compact so the
                // distance stays next to the name.
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: LotMiniCard.maxWidth,
                    ),
                    child: LotMiniCard(
                      key: ValueKey('lot-card-${selected.id}'),
                      lot: selected,
                      distanceMetres: switch (_userPosition) {
                        final LatLng user =>
                          haversineMetres(user, selected.position),
                        null => null,
                      },
                      onTap: () => _openLot(selected),
                    ),
                  ),
                ),
              ),
            ),
          if (adjusting)
            // US-1.3 AC2/AC3/AC5: above the attribution (BR-13).
            Positioned(
              left: 8,
              right: 8,
              bottom: 48,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: LotMiniCard.maxWidth,
                    ),
                    child: AdjustActions(
                      onCancel: _location.cancelAdjust,
                      onConfirm: _onConfirmAdjust,
                    ),
                  ),
                ),
              ),
            )
          else
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

  /// Top of the map outside adjust mode: the single banner (§3), empty
  /// states, "Search this area", loading, cap and "Locating…" hints.
  Widget _buildTopColumn(AppLocalizations l10n, MapBannerKind? bannerKind) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bannerKind != null)
          buildLocationBanner(
            context,
            bannerKind,
            _location,
            onRetry: _lots.retry,
          ),
        ..._buildEmptyState(l10n),
        if (_lots.showSearchArea)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ActionChip(
              key: const ValueKey('chip-search-area'),
              avatar: const Icon(Icons.search),
              label: Text(l10n.btn_search_area),
              onPressed: _lots.searchThisArea,
            ),
          ),
        if (_lots.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _LoadingChip(key: ValueKey('lots-loading')),
          ),
        if (_lots.showCapHint)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(
              key: const ValueKey('hint-cap'),
              label: Text(
                l10n.hint_cap(LotsRepository.maxLots),
                textAlign: TextAlign.center,
              ),
            ),
          ),
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
    );
  }

  /// US-1.2 AC4 empty states (below the single banner).
  List<Widget> _buildEmptyState(AppLocalizations l10n) {
    final empty = _lots.emptyState;
    if (empty == null) return const [];
    final Widget panel = switch (empty) {
      LotsEmptyState.radius => MapBanner(
          key: const ValueKey('empty-radius'),
          icon: Icons.search_off,
          text: l10n.empty_radius(LotsController.defaultRadiusM ~/ 1000),
          actionKey: const ValueKey('btn-expand'),
          actionLabel: l10n.btn_expand(LotsController.expandedRadiusM ~/ 1000),
          onAction: _lots.expand,
        ),
      LotsEmptyState.none => MapBanner(
          key: const ValueKey('empty-none'),
          icon: Icons.search_off,
          text: l10n.empty_none,
        ),
      LotsEmptyState.area => MapBanner(
          key: const ValueKey('empty-area'),
          icon: Icons.search_off,
          text: l10n.empty_area,
        ),
    };
    return [
      Padding(padding: const EdgeInsets.only(top: 8), child: panel),
    ];
  }
}

/// US-1.2 AC3: non-blocking progress chip (the map stays usable).
class _LoadingChip extends StatelessWidget {
  const _LoadingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shape: const StadiumBorder(),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// US-1.3 AC2: overflow menu (top right) with "Set my position".
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onSetPosition});

  final VoidCallback onSetPosition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      // Tooltip: the framework's localised "Show menu" (NFR-8).
      child: PopupMenuButton<void>(
        key: const ValueKey('map-menu'),
        icon: const Icon(Icons.more_vert),
        constraints: const BoxConstraints(minWidth: 112),
        itemBuilder: (context) => [
          PopupMenuItem<void>(
            key: const ValueKey('menu-set-position'),
            onTap: onSetPosition,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: Text(l10n.menu_set_position),
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
