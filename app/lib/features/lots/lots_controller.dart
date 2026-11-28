import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../location/location_controller.dart';
import 'connectivity_monitor.dart';
import 'lots_geo.dart';
import 'lots_repository.dart';
import 'parking_lot.dart';

/// Position-based search (BR-3 (a)–(c)) or "Search this area" (BR-3 (d)).
enum LotsSearchKind { position, area }

/// Empty states of SPEC-001 US-1.2 AC4.
enum LotsEmptyState {
  /// `empty_radius` at 1 km + "Expand to 3 km".
  radius,

  /// `empty_none`: still 0 after expanding, no further action.
  none,

  /// `empty_area`: "Search this area" found nothing, no Expand.
  area,
}

/// One `nearby_lots` request (point already per BR-14).
@immutable
class LotsRequest {
  const LotsRequest({
    required this.point,
    required this.radiusM,
    required this.kind,
  });

  final LatLng point;
  final int radiusM;
  final LotsSearchKind kind;

  @override
  bool operator ==(Object other) =>
      other is LotsRequest &&
      other.point == point &&
      other.radiusM == radiusM &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(point, radiusM, kind);
}

/// Nearby-lots state of the map screen (SPEC-001 US-1.2 AC1, AC3–AC6, AC9).
///
/// Loads only on BR-3 triggers: [onSearchTrigger] (a)/(b) (and (c) once
/// US-1.3 exists), [searchThisArea] (d), [retry] / [expand] / the single
/// automatic retry on reconnect (e). Pan/zoom never loads.
class LotsController extends ChangeNotifier {
  LotsController({
    required LotsRepository repository,
    ConnectivityMonitor? connectivity,
    Stopwatch Function()? stopwatchFactory,
  })  : _repository = repository,
        _stopwatchFactory = stopwatchFactory ?? Stopwatch.new {
    _reconnectSub = connectivity?.onReconnected.listen((_) => _onReconnected());
  }

  final LotsRepository _repository;
  final Stopwatch Function() _stopwatchFactory;
  StreamSubscription<void>? _reconnectSub;

  /// SPEC-001 BR-1 default radius / "Expand" radius.
  static const int defaultRadiusM = 1000;
  static const int expandedRadiusM = 3000;

  List<ParkingLot> _lots = const [];
  bool _loading = false;
  bool _error = false;
  LotsEmptyState? _empty;
  LotsRequest? _request;
  int _seq = 0;
  bool _autoRetryAvailable = false;
  bool _disposed = false;
  String? _selectedId;

  // "Search this area" (BR-3 (d)).
  LatLng? _searchCentre;
  double? _searchZoom;
  MapCamera? _camera;
  bool _gestureSinceSearch = false;
  bool _showSearchArea = false;

  /// Pins currently shown (kept while loading and on error, AC3/AC5).
  List<ParkingLot> get lots => _lots;

  /// AC3: a request is in flight (non-blocking chip).
  bool get isLoading => _loading;

  /// AC5: `error_load` banner + Retry (top banner priority, §3).
  bool get hasError => _error;

  /// AC4 empty state, or `null`.
  LotsEmptyState? get emptyState => _empty;

  /// AC9: exactly the BR-2 maximum was returned.
  bool get showCapHint => _lots.length >= LotsRepository.maxLots;

  /// AC6: "Search this area" chip.
  bool get showSearchArea => _showSearchArea;

  /// The last request sent (Retry repeats it).
  LotsRequest? get currentRequest => _request;

  /// AC8: the highlighted lot, or `null`.
  ParkingLot? get selectedLot {
    final id = _selectedId;
    if (id == null) return null;
    for (final lot in _lots) {
      if (lot.id == id) return lot;
    }
    return null;
  }

  // ------------------------------------------------------------ triggers

  /// BR-3 (a)–(c) from the location controller; [point] follows BR-14.
  /// Every new trigger starts again at 1 km (D5).
  void onSearchTrigger(LatLng point, SearchTrigger trigger) {
    _newSearch(LotsRequest(
      point: point,
      radiusM: defaultRadiusM,
      kind: LotsSearchKind.position,
    ));
  }

  /// BR-3 (d): around the map centre (BR-14, inside or outside the area),
  /// radius = half the visible diagonal clamped to [300, 5000] m.
  void searchThisArea() {
    final camera = _camera;
    if (camera == null) return;
    _newSearch(LotsRequest(
      point: camera.center,
      radiusM: SearchAreaRule.radiusFor(camera),
      kind: LotsSearchKind.area,
    ));
  }

  /// AC4 "Expand to 3 km": the current position-based search at 3000 m.
  void expand() {
    final request = _request;
    if (request == null || _empty != LotsEmptyState.radius) return;
    _load(LotsRequest(
      point: request.point,
      radiusM: expandedRadiusM,
      kind: request.kind,
    ));
  }

  /// AC5 "Retry": repeats the last request (same point and radius).
  void retry() {
    final request = _request;
    if (request != null) _load(request);
  }

  void _newSearch(LotsRequest request) {
    _autoRetryAvailable = true;
    _searchCentre = request.point;
    _searchZoom = _camera?.zoom;
    _gestureSinceSearch = false;
    _showSearchArea = false;
    _load(request);
  }

  /// AC5: exactly one automatic retry on offline → online, only while the
  /// error banner is shown; never on HTTP errors themselves.
  void _onReconnected() {
    if (_disposed || !_error || _loading || !_autoRetryAvailable) return;
    _autoRetryAvailable = false;
    retry();
  }

  Future<void> _load(LotsRequest request) async {
    final seq = ++_seq;
    _request = request;
    _loading = true;
    _empty = null;
    _notify();

    final watch = _stopwatchFactory()..start();
    final List<ParkingLot> result;
    try {
      result = await _repository.nearbyLots(
        point: request.point,
        radiusM: request.radiusM,
      );
    } catch (e) {
      if (_disposed || seq != _seq) return; // stale response
      _loading = false;
      _error = true;
      // NFR-6: no coordinates in logs.
      if (!kReleaseMode) {
        debugPrint('nearby_lots error: '
            '${e is LotsLoadException ? e.reason : e.runtimeType}');
      }
      _notify();
      return;
    }
    if (_disposed || seq != _seq) return; // stale response

    _loading = false;
    _error = false;
    _lots = List.unmodifiable(result);
    if (_selectedId != null && !_lots.any((l) => l.id == _selectedId)) {
      _selectedId = null;
    }
    if (result.isEmpty) {
      _empty = switch (request.kind) {
        LotsSearchKind.area => LotsEmptyState.area,
        LotsSearchKind.position => request.radiusM < expandedRadiusM
            ? LotsEmptyState.radius
            : LotsEmptyState.none,
      };
    }
    // NFR-1 client timer (debug/profile only, no coordinates).
    if (!kReleaseMode) {
      debugPrint('nearby_lots loaded count=${result.length} '
          'radius_m=${request.radiusM} trigger=${request.kind.name} '
          'duration_ms=${watch.elapsedMilliseconds}');
    }
    _notify();
  }

  // ------------------------------------------------------------ camera

  /// Every camera change (gesture or programmatic). Updates the chip only;
  /// never loads (AC6).
  void onCameraChanged(MapCamera camera, {required bool hasGesture}) {
    _camera = camera;
    if (hasGesture) {
      _gestureSinceSearch = true;
    } else if (!_gestureSinceSearch) {
      // Programmatic moves after a trigger (e.g. the zoom-16 animation of
      // US-1.1 AC2/AC8) set the reference zoom.
      _searchZoom = camera.zoom;
    }
    _searchZoom ??= camera.zoom;
    _updateChip();
  }

  /// A user-initiated zoom that is not a map gesture (cluster tap, AC7).
  void onUserZoom() {
    _gestureSinceSearch = true;
  }

  void _updateChip() {
    final camera = _camera;
    final centre = _searchCentre;
    final zoom = _searchZoom;
    final show = _gestureSinceSearch &&
        camera != null &&
        centre != null &&
        zoom != null &&
        SearchAreaRule.exceededFor(
          camera,
          searchCentre: centre,
          searchZoom: zoom,
        );
    if (show != _showSearchArea) {
      _showSearchArea = show;
      _notify();
    }
  }

  // ------------------------------------------------------------ selection

  /// AC8: highlight [lot] (or clear with `null`).
  void select(ParkingLot? lot) {
    if (_selectedId == lot?.id) return;
    _selectedId = lot?.id;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectSub?.cancel();
    super.dispose();
  }
}
