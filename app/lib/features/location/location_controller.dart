import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../map/map_constants.dart';
import 'location_service.dart';

/// Where the user's position comes from right now (SPEC-001 US-1.1).
enum LocationStatus {
  /// Consent not granted: no location API is ever called (BR-9, D3).
  consentDeclined,

  /// Checking / requesting the OS/browser permission.
  starting,

  /// Permission denied (once), or no location API (Web non-HTTPS, AC11).
  needed,

  /// Android "Don't ask again" / Web blocked (AC5).
  blocked,

  /// Permission granted but device location services off (Android, AC6).
  serviceOff,

  /// Stream running, no fix yet, < 10 s (AC9 timer running).
  locating,

  /// Timeout; showing a last-known position < 5 min old (AC9, Android).
  lastKnown,

  /// Timeout without last-known: default centre + `banner_no_fix` (AC9).
  noFix,

  /// Fresh GPS fixes (AC2, AC7).
  tracking,
}

/// The single banner shown on the map (SPEC-001 §3: max one).
///
/// [loadError] (US-1.2 AC5, `error_load` + Retry) has the top priority; it
/// comes from the lots controller, never from [LocationController.banner].
enum MapBannerKind { loadError, locationNeeded, locationOff, noFix, outOfArea }

/// BR-3 refresh triggers raised by US-1.1 (US-1.2 loads the lots).
enum SearchTrigger {
  /// BR-3 (a): first GPS fix, last-known, default centre, late first fix.
  firstPosition,

  /// BR-3 (b): "My location".
  myLocation,
}

/// Search-centre hook (US-1.1 AC8 → US-1.2). [point] already follows BR-14.
typedef SearchCentreCallback = void Function(
  LatLng point,
  SearchTrigger trigger,
);

/// Moves the map camera; `zoom == null` keeps the current zoom.
typedef CameraMover = void Function(LatLng centre, double? zoom);

typedef TimerFactory = Timer Function(Duration duration, void Function() cb);

/// Session-scoped map state (lives until app restart / page reload).
class MapSession {
  /// US-1.1 AC10: out-of-area banner closed (×) for the rest of the session.
  bool outOfAreaDismissed = false;
}

/// Location state machine of the map screen (SPEC-001 US-1.1 AC2–AC12).
///
/// Pure logic: UI callbacks ([moveCamera], [onShowUnblockGuide], …) are
/// injected; the clock and timers are injectable for tests.
class LocationController extends ChangeNotifier {
  LocationController({
    required LocationService? service,
    required this.session,
    required this.moveCamera,
    this.onSearchCentreChanged,
    this.onReopenConsent,
    this.onShowUnblockGuide,
    this.onAdjustRequested,
    DateTime Function()? clock,
    TimerFactory? timerFactory,
  })  : _service = service,
        _clock = clock ?? DateTime.now,
        _timerFactory = timerFactory ?? Timer.new,
        _status = service == null
            ? LocationStatus.consentDeclined
            : LocationStatus.starting;

  /// `null` when consent is not granted (BR-9): nothing can be called.
  final LocationService? _service;
  final MapSession session;
  final CameraMover moveCamera;
  final SearchCentreCallback? onSearchCentreChanged;

  /// "Enable" after a declined consent reopens S1 (AC3).
  final VoidCallback? onReopenConsent;

  /// Web: show `web_unblock_title` / `web_unblock_guide` (AC5).
  final VoidCallback? onShowUnblockGuide;

  /// "Adjust" on `banner_no_fix` (AC9). TODO(US-1.3): start adjust mode
  /// (US-1.3 AC2); until then this hook is a no-op.
  final VoidCallback? onAdjustRequested;

  final DateTime Function() _clock;
  final TimerFactory _timerFactory;

  /// SPEC-001 AC9: timeout for the first fix after permission is granted.
  static const Duration fixTimeout = Duration(seconds: 10);

  /// SPEC-001 AC9: max age of a usable last-known position.
  static const Duration lastKnownMaxAge = Duration(minutes: 5);

  /// SPEC-001 AC7 / NFR-5: minimum movement before the dot moves.
  static const double distanceFilterMetres = 10;

  /// SPEC-001 AC12: a fresh fix replacing last-known reloads only beyond this.
  static const double reloadThresholdMetres = 100;

  static const Distance _distance = Distance();

  LocationStatus _status;
  LocationFix? _fix;
  bool _followMode = false;
  bool _userPanned = false;
  bool _firstPositionDone = false;
  bool _requestInFlight = false;
  bool _paused = false;
  bool _disposed = false;
  LatLng? _lastSearchCentre;
  Timer? _timeout;
  StreamSubscription<LocationFix>? _positionSub;
  StreamSubscription<bool>? _serviceSub;

  LocationStatus get status => _status;

  /// The blue dot (GPS fix or last-known), or `null`.
  LocationFix? get userFix => _fix;

  /// AC7: the camera follows the dot while this is on.
  bool get followMode => _followMode;

  /// Last point passed to [onSearchCentreChanged].
  LatLng? get lastSearchCentre => _lastSearchCentre;

  /// AC9: "Locating…" hint while a last-known position is shown.
  bool get showLocatingHint => _status == LocationStatus.lastKnown;

  bool get isOutOfArea {
    final fix = _fix;
    return fix != null && !ServiceArea.contains(fix.position);
  }

  /// SPEC-001 §3 priority: offline/error (US-1.2) > permission / GPS /
  /// no fix > outside area > low accuracy (US-1.3). A dismissed banner is
  /// skipped and the next one in priority is shown.
  MapBannerKind? get banner {
    switch (_status) {
      case LocationStatus.consentDeclined:
      case LocationStatus.needed:
      case LocationStatus.blocked:
        return MapBannerKind.locationNeeded;
      case LocationStatus.serviceOff:
        return MapBannerKind.locationOff;
      case LocationStatus.noFix:
        return MapBannerKind.noFix;
      case LocationStatus.starting:
      case LocationStatus.locating:
      case LocationStatus.lastKnown:
      case LocationStatus.tracking:
        break;
    }
    if (isOutOfArea && !session.outOfAreaDismissed) {
      return MapBannerKind.outOfArea;
    }
    return null;
  }

  // ---------------------------------------------------------------- start

  /// Starts location handling. [requestPermission] is true right after
  /// "Allow" on S1 (US-1.4 AC3); otherwise the permission is only checked
  /// (no prompt on relaunch, no nagging).
  Future<void> start({required bool requestPermission}) async {
    final service = _service;
    if (service == null) {
      // Consent declined: default centre, no location call at all (AC3).
      _enterNoLocation(LocationStatus.consentDeclined);
      return;
    }
    _setStatus(LocationStatus.starting);
    final LocationPermissionStatus result;
    _requestInFlight = true;
    try {
      result = requestPermission
          ? await service.requestPermission()
          : await service.checkPermission();
    } finally {
      _requestInFlight = false;
    }
    if (_disposed) return;
    await _onPermission(result, fromEnable: false, fromCheck: !requestPermission);
  }

  Future<void> _onPermission(
    LocationPermissionStatus result, {
    required bool fromEnable,
    required bool fromCheck,
  }) async {
    switch (result) {
      case LocationPermissionStatus.granted:
        await _startTracking();
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.unavailable:
        _enterNoLocation(LocationStatus.needed); // AC4, AC11
      case LocationPermissionStatus.deniedForever:
        _enterNoLocation(LocationStatus.blocked); // AC5
        if (fromEnable && _service!.isWeb) onShowUnblockGuide?.call();
      case LocationPermissionStatus.unknown:
        // Web without the Permissions API: only the Geolocation API itself
        // can tell (Q-QA-22). Consent is granted, so start the stream; a
        // PERMISSION_DENIED error leads to `needed`.
        if (fromCheck) {
          await _startTracking();
        } else {
          _enterNoLocation(LocationStatus.needed);
        }
    }
  }

  Future<void> _startTracking() async {
    final service = _service!;
    if (service.canDetectServiceOff) {
      _serviceSub ??= service.serviceStatusStream().listen(_onServiceStatus);
      final enabled = await service.isLocationServiceEnabled();
      if (_disposed) return;
      if (!enabled) {
        _enterNoLocation(LocationStatus.serviceOff); // AC6
        return;
      }
    }
    if (_paused) {
      // Prompt answered while backgrounded: resume() starts the stream.
      if (!_hasPositionStatus) _setStatus(LocationStatus.locating);
      return;
    }
    _subscribe();
    if (!_hasPositionStatus) _setStatus(LocationStatus.locating);
    // AC9 / AC6: 10 s from permission granted or from returning to the
    // foreground without a fix yet.
    if (_status == LocationStatus.locating) _startTimeout();
  }

  bool get _hasPositionStatus =>
      _status == LocationStatus.locating ||
      _status == LocationStatus.lastKnown ||
      _status == LocationStatus.noFix ||
      _status == LocationStatus.tracking;

  void _subscribe() {
    _positionSub?.cancel();
    _positionSub = _service!.positionStream().listen(
          _onFix,
          onError: _onStreamError,
          cancelOnError: false,
        );
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = _timerFactory(fixTimeout, _onTimeout);
  }

  void _stopTracking() {
    _timeout?.cancel();
    _timeout = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// No usable location: default centre (BR-5), BR-3 (a) search once.
  ///
  /// For [LocationStatus.noFix] the stream keeps running so a late fix can
  /// still arrive (AC12); for all other states it is stopped and the dot is
  /// removed.
  void _enterNoLocation(LocationStatus status) {
    if (status != LocationStatus.noFix) {
      _stopTracking();
      _fix = null;
      _followMode = false;
    }
    _status = status;
    if (!_firstPositionDone) {
      _firstPositionDone = true;
      _search(MapConstants.defaultCentre, SearchTrigger.firstPosition);
    }
    _notify();
  }

  // ---------------------------------------------------------------- fixes

  Future<void> _onTimeout() async {
    _timeout = null;
    if (_disposed || _status != LocationStatus.locating) return;
    final service = _service!;
    if (service.supportsLastKnown) {
      final last = await service.lastKnownPosition();
      if (_disposed || _status != LocationStatus.locating) return;
      if (last != null &&
          _clock().difference(last.timestamp) < lastKnownMaxAge) {
        _status = LocationStatus.lastKnown;
        _fix = last;
        _firstPosition(last);
        _notify();
        return;
      }
    }
    _enterNoLocation(LocationStatus.noFix);
  }

  void _onFix(LocationFix fix) {
    if (_disposed) return;
    final previous = _fix;
    final wasStatus = _status;

    // AC7 / NFR-5: 10 m distance filter between fresh fixes.
    if (wasStatus == LocationStatus.tracking &&
        previous != null &&
        _metres(previous.position, fix.position) < distanceFilterMetres) {
      return;
    }

    _timeout?.cancel();
    _timeout = null;
    _fix = fix;
    _status = LocationStatus.tracking;

    switch (wasStatus) {
      case LocationStatus.locating:
      case LocationStatus.starting:
        _firstPosition(fix); // AC2
      case LocationStatus.noFix:
        // AC12: late fix after the timeout.
        if (!_userPanned) {
          _firstPosition(fix);
        }
      // Otherwise: blue dot only, no camera jump, no reload.
      // TODO(US-1.3): also "no manual position set" (AC12, US-1.3 AC4).
      case LocationStatus.lastKnown:
        // AC12: fresh fix replaces last-known; reload once only if the
        // new search point is > 100 m from the last search centre.
        if (_followMode) moveCamera(fix.position, null);
        final point = ServiceArea.searchPointFor(fix.position);
        final last = _lastSearchCentre;
        if (last == null || _metres(last, point) > reloadThresholdMetres) {
          _search(point, SearchTrigger.firstPosition);
        }
      case LocationStatus.tracking:
        if (_followMode) moveCamera(fix.position, null); // AC7
      case LocationStatus.consentDeclined:
      case LocationStatus.needed:
      case LocationStatus.blocked:
      case LocationStatus.serviceOff:
        // A fix while a no-location state is shown (e.g. stream restarted
        // late): treat like a first fix if the user has not panned.
        if (!_userPanned) _firstPosition(fix);
    }
    _notify();
  }

  /// AC2 / BR-3 (a): camera to the position at zoom 16, follow on, search.
  void _firstPosition(LocationFix fix) {
    _firstPositionDone = true;
    _followMode = true;
    _userPanned = false;
    moveCamera(fix.position, MapConstants.userZoom);
    _search(ServiceArea.searchPointFor(fix.position), SearchTrigger.firstPosition);
  }

  void _onStreamError(Object error) {
    if (_disposed) return;
    if (error is LocationPermissionDeniedError) {
      _enterNoLocation(LocationStatus.needed); // AC4 / US-1.4 AC8
    } else if (error is LocationServiceDisabledError) {
      unawaited(_onServiceDisabledError());
    } else {
      // Position unavailable / timeout (e.g. Web GPS off): AC9 timer
      // handles it. No coordinates in this log.
      debugPrint('Location stream error: ${error.runtimeType}');
    }
  }

  /// The stream reports "location services disabled". On Android this is
  /// also raised when the user declines Google Play services' "Location
  /// Accuracy" dialog while device location is ON (issue #31). Only the
  /// real service state decides AC6; a declined accuracy dialog is treated
  /// as "no fix yet", so the AC9 timeout (last-known / `banner_no_fix`)
  /// takes over.
  Future<void> _onServiceDisabledError() async {
    final enabled = await _service!.isLocationServiceEnabled();
    if (_disposed) return;
    if (!enabled) {
      _enterNoLocation(LocationStatus.serviceOff); // AC6
    } else {
      debugPrint('Location stream: settings check declined, services on');
    }
  }

  void _onServiceStatus(bool enabled) {
    if (_disposed) return;
    if (!enabled && _hasPositionStatus) {
      _enterNoLocation(LocationStatus.serviceOff);
    } else if (enabled && _status == LocationStatus.serviceOff && !_paused) {
      unawaited(_startTracking());
    }
  }

  void _search(LatLng point, SearchTrigger trigger) {
    _lastSearchCentre = point;
    onSearchCentreChanged?.call(point, trigger);
  }

  // ---------------------------------------------------------------- user

  /// The user panned / zoomed the map by gesture (AC7): follow mode off.
  void onUserGesture() {
    _userPanned = true;
    if (_followMode) {
      _followMode = false;
      _notify();
    }
  }

  /// "My location" FAB (AC8).
  void onMyLocation() {
    final fix = _fix;
    if (fix != null) {
      _followMode = true;
      _userPanned = false;
      moveCamera(fix.position, MapConstants.userZoom);
      _search(ServiceArea.searchPointFor(fix.position), SearchTrigger.myLocation);
      _notify();
      return;
    }
    // No position: run the action of the current banner (cf. US-1.3 AC4).
    switch (banner) {
      case MapBannerKind.locationNeeded:
        unawaited(onEnable());
      case MapBannerKind.locationOff:
        unawaited(onTurnOn());
      case MapBannerKind.noFix:
      case MapBannerKind.outOfArea:
      case MapBannerKind.loadError:
      case null:
        break;
    }
  }

  /// "Enable" on `banner_location_needed` (AC3, AC4, AC5).
  Future<void> onEnable() async {
    final service = _service;
    if (service == null) {
      onReopenConsent?.call(); // AC3: reopen S1
      return;
    }
    if (_requestInFlight) return;
    if (_status == LocationStatus.blocked && service.canOpenSettings) {
      await service.openAppSettings(); // AC5 Android; resume() re-checks
      return;
    }
    // AC4 re-request; Web (Q-QA-22): one Geolocation API call, a
    // PERMISSION_DENIED shows the unblock guide.
    _requestInFlight = true;
    final LocationPermissionStatus result;
    try {
      result = await service.requestPermission();
    } finally {
      _requestInFlight = false;
    }
    if (_disposed) return;
    await _onPermission(result, fromEnable: true, fromCheck: false);
  }

  /// "Turn on" on `banner_location_off` (AC6, Android only).
  Future<void> onTurnOn() async {
    await _service?.openLocationSettings();
  }

  /// "Adjust" on `banner_no_fix` (AC9 → US-1.3 AC2, not built yet).
  void onAdjust() => onAdjustRequested?.call();

  /// "Go to Vũng Tàu" (AC10): default centre at zoom 15, follow off.
  void onGoToVungTau() {
    _followMode = false;
    moveCamera(MapConstants.defaultCentre, MapConstants.initialZoom);
    _notify();
  }

  /// × on the out-of-area banner (AC10): hidden for the rest of the session.
  void onDismissOutOfArea() {
    session.outOfAreaDismissed = true;
    _notify();
  }

  // ---------------------------------------------------------------- lifecycle

  /// App backgrounded: stop the stream (NFR-5).
  void pause() {
    if (_paused) return;
    _paused = true;
    _timeout?.cancel();
    _timeout = null;
    _positionSub?.cancel();
    _positionSub = null;
  }

  /// App back in the foreground: re-check permission / location services
  /// (AC5 return from settings, AC6 fix after turning GPS on, TC-1.4.6).
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    final service = _service;
    if (service == null || _requestInFlight) return;
    if (_status == LocationStatus.starting) return;

    final result = await service.checkPermission();
    if (_disposed || _paused) return;
    switch (result) {
      case LocationPermissionStatus.granted:
        await _startTracking();
      case LocationPermissionStatus.denied:
        _enterNoLocation(LocationStatus.needed);
      case LocationPermissionStatus.deniedForever:
        _enterNoLocation(LocationStatus.blocked);
      case LocationPermissionStatus.unavailable:
        if (_hasPositionStatus) _enterNoLocation(LocationStatus.needed);
      case LocationPermissionStatus.unknown:
        // Web without Permissions API: keep the state; restart the stream
        // if it was running.
        if (_hasPositionStatus) await _startTracking();
    }
  }

  double _metres(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

  void _setStatus(LocationStatus status) {
    if (_status == status) return;
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTracking();
    _serviceSub?.cancel();
    _serviceSub = null;
    super.dispose();
  }
}
