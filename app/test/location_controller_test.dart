import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:parkfinder/features/location/location_controller.dart';
import 'package:parkfinder/features/location/location_service.dart';
import 'package:parkfinder/features/map/map_constants.dart';

import 'helpers/fakes.dart';

/// SPEC-001 US-1.1 AC2–AC12 — unit tests of the location state machine with
/// a fake [LocationService], fake timers and a fake clock.

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class _Harness {
  _Harness({
    FakeLocationService? service,
    bool consentGranted = true,
    MapSession? session,
  })  : service = service ?? FakeLocationService(),
        session = session ?? MapSession() {
    controller = LocationController(
      service: consentGranted ? this.service : null,
      session: this.session,
      moveCamera: (centre, zoom) => moves.add((centre: centre, zoom: zoom)),
      onSearchCentreChanged: (point, trigger) =>
          searches.add((point: point, trigger: trigger)),
      onReopenConsent: () => reopenConsent++,
      onShowUnblockGuide: () => unblockGuides++,
      onUsingGps: () => usingGps++,
      clock: () => now,
      timerFactory: (d, cb) {
        final t = _FakeTimer(d, cb);
        timers.add(t);
        return t;
      },
    );
  }

  final FakeLocationService service;
  final MapSession session;
  late final LocationController controller;
  final moves = <({LatLng centre, double? zoom})>[];
  final searches = <({LatLng point, SearchTrigger trigger})>[];
  final timers = <_FakeTimer>[];
  DateTime now = testNow;
  int reopenConsent = 0;
  int unblockGuides = 0;
  int usingGps = 0;

  _FakeTimer? get activeTimer =>
      timers.where((t) => t.isActive).lastOrNull;

  Future<void> start({bool request = true}) async {
    await controller.start(requestPermission: request);
    await flush();
  }

  Future<void> emit(LocationFix fix) async {
    service.emit(fix);
    await flush();
  }

  Future<void> fireTimeout() async {
    final t = activeTimer!;
    expect(t.duration, const Duration(seconds: 10));
    t.fire();
    await flush();
  }

  Future<void> background() async {
    controller.pause();
    await flush();
  }

  Future<void> foreground() async {
    await controller.resume();
    await flush();
  }
}

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

LocationFix _offsetNorth(LocationFix fix, double metres) => LocationFix(
      position: const Distance().offset(fix.position, metres, 0),
      accuracy: fix.accuracy,
      timestamp: fix.timestamp,
    );

void main() {
  group('consent gate (BR-9, D3, AC3)', () {
    test('declined: no location call, default centre search, banner; '
        'Enable reopens S1', () async {
      final h = _Harness(consentGranted: false);
      await h.start();

      expect(h.service.totalCalls, 0);
      expect(h.controller.status, LocationStatus.consentDeclined);
      expect(h.controller.banner, MapBannerKind.locationNeeded);
      expect(h.searches.single.point, MapConstants.defaultCentre);
      expect(h.searches.single.trigger, SearchTrigger.firstPosition);
      expect(h.moves, isEmpty); // stays on the default centre (BR-5)

      await h.controller.onEnable();
      h.controller.onMyLocation();
      await h.background();
      await h.foreground();
      expect(h.reopenConsent, 2); // Enable + My location
      expect(h.service.totalCalls, 0);
    });

    test('relaunch with consent granted only checks, never prompts', () async {
      final h = _Harness();
      await h.start(request: false);
      expect(h.service.checkCalls, 1);
      expect(h.service.requestCalls, 0);
      expect(h.service.isStreaming, isTrue);
    });

    test('relaunch with permission denied → banner, no prompt (no nagging)',
        () async {
      final h = _Harness(
        service: FakeLocationService(
          checkResult: LocationPermissionStatus.denied,
        ),
      );
      await h.start(request: false);
      expect(h.service.requestCalls, 0);
      expect(h.controller.banner, MapBannerKind.locationNeeded);
    });
  });

  group('AC2 granted', () {
    test('first fix → camera at zoom 16, follow on, dot, search', () async {
      final h = _Harness();
      await h.start();
      expect(h.service.requestCalls, 1);
      expect(h.controller.status, LocationStatus.locating);
      expect(h.controller.banner, isNull);

      await h.emit(MockPoints.mp1);

      expect(h.controller.status, LocationStatus.tracking);
      expect(h.controller.userFix, MockPoints.mp1);
      expect(h.controller.userFix!.accuracy, 20);
      expect(h.controller.followMode, isTrue);
      expect(h.moves.single.centre, MockPoints.mp1.position);
      expect(h.moves.single.zoom, 16);
      expect(h.searches.single.point, MockPoints.mp1.position);
      expect(h.searches.single.trigger, SearchTrigger.firstPosition);
      expect(h.activeTimer, isNull); // timeout cancelled
      expect(h.controller.banner, isNull);
    });
  });

  group('AC4 denied once', () {
    test('banner; Enable re-requests the permission', () async {
      final h = _Harness(
        service: FakeLocationService(
          requestResult: LocationPermissionStatus.denied,
        ),
      );
      await h.start();
      expect(h.controller.status, LocationStatus.needed);
      expect(h.controller.banner, MapBannerKind.locationNeeded);
      expect(h.searches.single.point, MapConstants.defaultCentre);
      expect(h.service.isStreaming, isFalse);

      h.service.requestResult = LocationPermissionStatus.granted;
      await h.controller.onEnable();
      await flush();
      expect(h.service.requestCalls, 2);
      expect(h.reopenConsent, 0);
      expect(h.controller.status, LocationStatus.locating);

      await h.emit(MockPoints.mp1);
      expect(h.controller.banner, isNull);
      expect(h.moves.last.zoom, 16);
    });
  });

  group('AC5 denied forever / blocked', () {
    test('Android: Enable opens app settings; granted on return → dot '
        'without restart', () async {
      final h = _Harness(
        service: FakeLocationService(
          requestResult: LocationPermissionStatus.deniedForever,
        ),
      );
      await h.start();
      expect(h.controller.status, LocationStatus.blocked);
      expect(h.controller.banner, MapBannerKind.locationNeeded);

      await h.controller.onEnable();
      expect(h.service.openAppSettingsCalls, 1);
      expect(h.service.requestCalls, 1); // no new prompt
      expect(h.unblockGuides, 0);

      await h.background();
      h.service.checkResult = LocationPermissionStatus.granted;
      await h.foreground();
      expect(h.service.isStreaming, isTrue);
      await h.emit(MockPoints.mp1);
      expect(h.controller.userFix, MockPoints.mp1);
      expect(h.controller.banner, isNull);
    });

    test('Web: blocked after Allow shows the banner (no guide yet); Enable '
        'calls the Geolocation API once and shows the guide', () async {
      final h = _Harness(
        service: FakeLocationService(
          isWeb: true,
          requestResult: LocationPermissionStatus.deniedForever,
        ),
      );
      await h.start();
      expect(h.controller.banner, MapBannerKind.locationNeeded);
      expect(h.unblockGuides, 0);

      await h.controller.onEnable();
      expect(h.service.requestCalls, 2);
      expect(h.service.openAppSettingsCalls, 0);
      expect(h.unblockGuides, 1);

      // Unblocked + Enable again → tracking.
      h.service.requestResult = LocationPermissionStatus.granted;
      await h.controller.onEnable();
      await flush();
      await h.emit(MockPoints.mp1);
      expect(h.controller.userFix, MockPoints.mp1);
      expect(h.controller.banner, isNull);
    });

    test('Web: PERMISSION_DENIED on the stream → banner; Enable → guide',
        () async {
      final h = _Harness(
        service: FakeLocationService(
          isWeb: true,
          checkResult: LocationPermissionStatus.unknown, // no Permissions API
        ),
      );
      await h.start(request: false);
      expect(h.service.isStreaming, isTrue);
      h.service.emitError(const LocationPermissionDeniedError());
      await flush();
      expect(h.controller.status, LocationStatus.needed);
      expect(h.controller.banner, MapBannerKind.locationNeeded);

      h.service.requestResult = LocationPermissionStatus.deniedForever;
      await h.controller.onEnable();
      expect(h.unblockGuides, 1);
    });

    test('Web resume with granted (Permissions API) → dot without reload',
        () async {
      final h = _Harness(
        service: FakeLocationService(
          isWeb: true,
          requestResult: LocationPermissionStatus.deniedForever,
        ),
      );
      await h.start();
      await h.background();
      h.service.checkResult = LocationPermissionStatus.granted;
      await h.foreground();
      expect(h.service.isStreaming, isTrue);
    });
  });

  group('AC6 GPS off (Android only)', () {
    test('banner + Turn on; fix after returning with location on', () async {
      final h = _Harness(service: FakeLocationService(serviceEnabled: false));
      await h.start();
      expect(h.controller.status, LocationStatus.serviceOff);
      expect(h.controller.banner, MapBannerKind.locationOff);
      expect(h.service.isStreaming, isFalse);
      expect(h.searches.single.point, MapConstants.defaultCentre);

      await h.controller.onTurnOn();
      expect(h.service.openLocationSettingsCalls, 1);

      await h.background();
      h.service.serviceEnabled = true;
      await h.foreground();
      // Stream restarted immediately on return to the foreground.
      expect(h.service.isStreaming, isTrue);
      expect(h.controller.status, LocationStatus.locating);
      expect(h.controller.banner, isNull);

      await h.emit(MockPoints.mp1);
      expect(h.controller.userFix, MockPoints.mp1);
      expect(h.moves.single.zoom, 16); // handled as first fix
    });

    test('location switched off/on while open (service status stream)',
        () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp1);

      h.service.emitServiceStatus(false);
      await flush();
      expect(h.controller.banner, MapBannerKind.locationOff);
      expect(h.controller.userFix, isNull);
      expect(h.service.isStreaming, isFalse);

      h.service.emitServiceStatus(true);
      await flush();
      expect(h.service.isStreaming, isTrue);
      expect(h.controller.banner, isNull);
    });

    test('stream reports location disabled → banner', () async {
      final h = _Harness();
      await h.start();
      h.service.emitError(const LocationServiceDisabledError());
      await flush();
      expect(h.controller.banner, MapBannerKind.locationOff);
    });

    test('Web: no service check, no Turn on; handled as timeout', () async {
      final h = _Harness(service: FakeLocationService(isWeb: true));
      await h.start();
      expect(h.service.serviceEnabledCalls, 0);
      await h.fireTimeout();
      expect(h.service.lastKnownCalls, 0); // Web: no last-known (Q-QA-8)
      expect(h.controller.banner, MapBannerKind.noFix);
    });
  });

  group('AC7 movement / follow mode', () {
    test('10 m distance filter; follows while follow mode on; pan turns it '
        'off', () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp1);
      expect(h.moves, hasLength(1));

      // 5 m: the dot does not move (TC-1.1.14).
      await h.emit(_offsetNorth(MockPoints.mp1, 5));
      expect(h.controller.userFix, MockPoints.mp1);
      expect(h.moves, hasLength(1));

      // 15 m from the shown dot: the dot moves, camera follows (zoom kept).
      final moved = _offsetNorth(MockPoints.mp1, 15);
      await h.emit(moved);
      expect(h.controller.userFix, moved);
      expect(h.moves, hasLength(2));
      expect(h.moves.last.centre, moved.position);
      expect(h.moves.last.zoom, isNull);
      expect(h.searches, hasLength(1)); // moving never reloads (BR-3)

      h.controller.onUserGesture();
      expect(h.controller.followMode, isFalse);

      final moved2 = _offsetNorth(moved, 50);
      await h.emit(moved2);
      expect(h.controller.userFix, moved2); // dot moves
      expect(h.moves, hasLength(2)); // camera does not follow
    });
  });

  group('AC8 My location', () {
    test('recenters at zoom 16, follow on, search hook fired', () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp1);
      h.controller.onUserGesture();
      final now = _offsetNorth(MockPoints.mp1, 200);
      await h.emit(now);

      h.controller.onMyLocation();

      expect(h.controller.followMode, isTrue);
      expect(h.moves.last.centre, now.position);
      expect(h.moves.last.zoom, 16);
      expect(h.searches.last.trigger, SearchTrigger.myLocation);
      expect(h.searches.last.point, now.position);
    });

    test('without a position runs the banner action', () async {
      final h = _Harness(service: FakeLocationService(serviceEnabled: false));
      await h.start();
      h.controller.onMyLocation();
      await flush();
      expect(h.service.openLocationSettingsCalls, 1);
    });
  });

  group('AC9 timeout', () {
    test('no fix in 10 s, no last-known → default centre + no-fix banner',
        () async {
      final h = _Harness();
      await h.start();
      expect(h.searches, isEmpty);

      await h.fireTimeout();

      expect(h.service.lastKnownCalls, 1);
      expect(h.controller.status, LocationStatus.noFix);
      expect(h.controller.banner, MapBannerKind.noFix);
      expect(h.controller.showLocatingHint, isFalse);
      expect(h.searches.single.point, MapConstants.defaultCentre);
      expect(h.service.isStreaming, isTrue); // late fix still possible

      h.controller.onAdjust();
      expect(h.controller.isAdjusting, isTrue); // US-1.3 AC2
    });

    test('last-known < 5 min (Android) → shown with Locating…, search',
        () async {
      final h = _Harness(
        service: FakeLocationService(
          lastKnown: fixAt(10.3500, 107.0820,
              at: testNow.subtract(const Duration(minutes: 4, seconds: 59))),
        ),
      );
      await h.start();
      await h.fireTimeout();

      expect(h.controller.status, LocationStatus.lastKnown);
      expect(h.controller.showLocatingHint, isTrue);
      expect(h.controller.banner, isNull);
      expect(h.controller.userFix!.position, const LatLng(10.3500, 107.0820));
      expect(h.moves.single.zoom, 16);
      expect(h.searches.single.point, const LatLng(10.3500, 107.0820));
    });

    test('last-known exactly 5 min / 6 min old → not used', () async {
      for (final age in const [Duration(minutes: 5), Duration(minutes: 6)]) {
        final h = _Harness(
          service: FakeLocationService(
            lastKnown: fixAt(10.35, 107.08, at: testNow.subtract(age)),
          ),
        );
        await h.start();
        await h.fireTimeout();
        expect(h.controller.status, LocationStatus.noFix, reason: '$age');
        expect(h.controller.userFix, isNull);
      }
    });

    test('a fix before the timeout cancels it', () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp1);
      expect(h.timers.every((t) => !t.isActive), isTrue);
      expect(h.service.lastKnownCalls, 0);
    });
  });

  group('AC12 late fix', () {
    test('untouched map → handled as first fix, banner removed', () async {
      final h = _Harness();
      await h.start();
      await h.fireTimeout();

      await h.emit(MockPoints.mp4);

      expect(h.controller.status, LocationStatus.tracking);
      expect(h.controller.banner, isNull);
      expect(h.controller.followMode, isTrue);
      expect(h.moves.single.centre, MockPoints.mp4.position);
      expect(h.moves.single.zoom, 16);
      expect(h.searches, hasLength(2));
      expect(h.searches.last.point, MockPoints.mp4.position);
      expect(h.searches.last.trigger, SearchTrigger.firstPosition);
    });

    test('after a pan → only the dot (no camera jump, no reload)', () async {
      final h = _Harness();
      await h.start();
      await h.fireTimeout();
      h.controller.onUserGesture();

      await h.emit(MockPoints.mp4);

      expect(h.controller.userFix, MockPoints.mp4);
      expect(h.moves, isEmpty);
      expect(h.searches, hasLength(1));
      expect(h.controller.followMode, isFalse);

      h.controller.onMyLocation();
      expect(h.moves.single.zoom, 16);
      expect(h.searches.last.trigger, SearchTrigger.myLocation);
    });

    test('fresh fix replaces last-known: reload only if > 100 m', () async {
      final last = fixAt(10.3500, 107.0820,
          at: testNow.subtract(const Duration(minutes: 1)));
      for (final (metres, reloads) in const [(60.0, 0), (150.0, 1)]) {
        final h = _Harness(service: FakeLocationService(lastKnown: last));
        await h.start();
        await h.fireTimeout();
        expect(h.searches, hasLength(1));

        await h.emit(_offsetNorth(last, metres));

        expect(h.controller.status, LocationStatus.tracking);
        expect(h.controller.showLocatingHint, isFalse);
        expect(h.searches, hasLength(1 + reloads), reason: '$metres m');
      }
    });
  });

  group('AC10 outside service area', () {
    test('dot at the fix, search at default centre, banner; Go to Vũng Tàu; '
        '× hides it for the session', () async {
      final session = MapSession();
      final h = _Harness(session: session);
      await h.start();
      await h.emit(MockPoints.mp6);

      expect(h.controller.userFix, MockPoints.mp6);
      expect(h.moves.single.centre, MockPoints.mp6.position);
      expect(h.searches.single.point, MapConstants.defaultCentre); // BR-14
      expect(h.controller.banner, MapBannerKind.outOfArea);

      h.controller.onGoToVungTau();
      expect(h.moves.last.centre, MapConstants.defaultCentre);
      expect(h.moves.last.zoom, 15);
      expect(h.controller.followMode, isFalse);

      // Moving 50 m at MP-6: camera stays on Vũng Tàu.
      await h.emit(_offsetNorth(MockPoints.mp6, 50));
      expect(h.moves, hasLength(2));

      h.controller.onDismissOutOfArea();
      expect(h.controller.banner, isNull);

      // My location while outside: search point stays the default centre.
      h.controller.onMyLocation();
      expect(h.searches.last.point, MapConstants.defaultCentre);
      expect(h.controller.banner, isNull);

      // Same session (e.g. map rebuilt): still hidden.
      final h2 = _Harness(session: session);
      await h2.start();
      await h2.emit(MockPoints.mp6);
      expect(h2.controller.banner, isNull);
    });

    test('§3 priority: permission/GPS banner wins over out-of-area', () async {
      final last = fixAt(10.7769, 106.7009,
          at: testNow.subtract(const Duration(minutes: 1)));
      final h = _Harness(service: FakeLocationService(lastKnown: last));
      await h.start();
      await h.fireTimeout();
      expect(h.controller.banner, MapBannerKind.outOfArea);
      h.service.emitServiceStatus(false);
      await flush();
      expect(h.controller.banner, MapBannerKind.locationOff);
    });
  });

  group('BR-12 service area, edges inclusive (TC-1.1.15)', () {
    test('edges and corners inside, just outside is outside', () {
      const inside = [
        LatLng(10.3000, 107.1000),
        LatLng(10.4500, 107.1000),
        LatLng(10.3500, 107.0300),
        LatLng(10.3500, 107.2000),
        LatLng(10.4500, 107.2000),
        LatLng(10.3001, 107.1000),
      ];
      for (final p in inside) {
        expect(ServiceArea.contains(p), isTrue, reason: '$p');
        expect(ServiceArea.searchPointFor(p), p);
      }
      const outside = [
        LatLng(10.2999, 107.1000),
        LatLng(10.7769, 106.7009),
        LatLng(10.3500, 107.2001),
      ];
      for (final p in outside) {
        expect(ServiceArea.contains(p), isFalse, reason: '$p');
        expect(ServiceArea.searchPointFor(p), MapConstants.defaultCentre);
      }
    });
  });

  group('AC11 / NFR-5 / lifecycle', () {
    test('Geolocation API unavailable → AC3 behaviour, Enable is harmless',
        () async {
      final h = _Harness(
        service: FakeLocationService(
          isWeb: true,
          requestResult: LocationPermissionStatus.unavailable,
        ),
      );
      await h.start();
      expect(h.controller.banner, MapBannerKind.locationNeeded);
      expect(h.searches.single.point, MapConstants.defaultCentre);
      await h.controller.onEnable();
      expect(h.unblockGuides, 0);
      expect(h.controller.banner, MapBannerKind.locationNeeded);
    });

    test('background stops the stream; foreground restarts it', () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp1);
      await h.background();
      expect(h.service.isStreaming, isFalse);
      await h.foreground();
      expect(h.service.isStreaming, isTrue);
      expect(h.controller.userFix, MockPoints.mp1);
    });

    test('locating in background: timeout restarts on return', () async {
      final h = _Harness();
      await h.start();
      await h.background();
      expect(h.activeTimer, isNull);
      await h.foreground();
      expect(h.activeTimer, isNotNull);
    });

    test('permission revoked while backgrounded (TC-1.4.6) → banner, dot '
        'removed', () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp1);
      await h.background();
      h.service.checkResult = LocationPermissionStatus.denied;
      await h.foreground();
      expect(h.controller.banner, MapBannerKind.locationNeeded);
      expect(h.controller.userFix, isNull);
      expect(h.service.isStreaming, isFalse);
    });

    test('dispose cancels stream and timer', () async {
      final h = _Harness();
      await h.start();
      h.controller.dispose();
      expect(h.service.isStreaming, isFalse);
      expect(h.activeTimer, isNull);
    });

    test('LocationFix never prints coordinates (NFR-6)', () {
      expect(MockPoints.mp1.toString(), isNot(contains('10.')));
    });
  });

  // ------------------------------------------------------------ US-1.3

  group('US-1.3 AC1 low accuracy (BR-7, D6)', () {
    test('TC-1.3.8: 100 m is not low, 101 m is', () async {
      final h = _Harness();
      await h.start();
      await h.emit(fixAt(10.3460, 107.0740, accuracy: 100));
      expect(h.controller.isLowAccuracy, isFalse);
      expect(h.controller.banner, isNull);

      final h2 = _Harness();
      await h2.start();
      await h2.emit(fixAt(10.3460, 107.0740, accuracy: 101));
      expect(h2.controller.isLowAccuracy, isTrue);
      expect(h2.controller.banner, MapBannerKind.lowAccuracy);
    });

    test('approximate-only permission (Android 12+) is low accuracy', () async {
      final h = _Harness(service: FakeLocationService(approximateOnly: true));
      await h.start();
      await h.emit(fixAt(10.3460, 107.0740, accuracy: 20));
      expect(h.controller.banner, MapBannerKind.lowAccuracy);
    });

    test('TC-1.3.1 / TC-1.3.14: × hides it for the session, also on new '
        'low-accuracy fixes; a new session shows it again', () async {
      final session = MapSession();
      final h = _Harness(session: session);
      await h.start();
      await h.emit(MockPoints.mp3LowAccuracy);
      expect(h.controller.banner, MapBannerKind.lowAccuracy);

      h.controller.onDismissLowAccuracy();
      expect(h.controller.banner, isNull);
      await h.emit(fixAt(10.3460, 107.0740, accuracy: 20));
      await h.emit(fixAt(10.3265, 107.0845, accuracy: 150));
      await h.background();
      await h.foreground();
      expect(h.controller.isLowAccuracy, isTrue);
      expect(h.controller.banner, isNull);

      final restarted = _Harness(); // new MapSession = app restart
      await restarted.start();
      await restarted.emit(MockPoints.mp3LowAccuracy);
      expect(restarted.controller.banner, MapBannerKind.lowAccuracy);
    });

    test(
      '§3 priority: outside area > low accuracy; dismissed → next',
      () async {
        final h = _Harness();
        await h.start();
        await h.emit(fixAt(10.7769, 106.7009, accuracy: 500)); // MP-6
        expect(h.controller.banner, MapBannerKind.outOfArea);
        h.controller.onDismissOutOfArea();
        expect(h.controller.banner, MapBannerKind.lowAccuracy);
      },
    );

    test('Adjust starts adjust mode', () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp3LowAccuracy);
      h.controller.onAdjust();
      expect(h.controller.isAdjusting, isTrue);
      expect(h.controller.followMode, isFalse);
    });
  });

  group('US-1.3 AC2–AC8 manual position', () {
    const manual = LatLng(10.3500, 107.0820); // MP-4

    Future<_Harness> tracking() async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp1);
      h.moves.clear();
      h.searches.clear();
      return h;
    }

    test('AC3 / TC-1.3.2: confirm → manual replaces the dot, BR-3 (c) '
        'search at the manual point, distances from it', () async {
      final h = await tracking();
      h.controller.startAdjust();
      h.controller.startAdjust(); // idempotent (long-press in adjust mode)
      expect(h.controller.isAdjusting, isTrue);
      expect(h.searches, isEmpty);

      h.controller.confirmAdjust(manual);
      expect(h.controller.isAdjusting, isFalse);
      expect(h.controller.manualPosition, manual);
      expect(h.controller.userPosition, manual); // BR-8 / BR-11
      expect(h.controller.blueDot, isNull);
      expect(h.searches.single.point, manual);
      expect(h.searches.single.trigger, SearchTrigger.manualPosition);
    });

    test('AC5 / TC-1.3.4: cancel → nothing changes, no search', () async {
      final h = await tracking();
      h.controller.startAdjust();
      h.controller.cancelAdjust();
      expect(h.controller.isAdjusting, isFalse);
      expect(h.controller.manualPosition, isNull);
      expect(h.controller.userPosition, MockPoints.mp1.position);
      expect(h.controller.blueDot, isNotNull);
      expect(h.searches, isEmpty);
      expect(h.moves, isEmpty);
    });

    test('adjust mode: GPS fixes never move the camera', () async {
      final h = await tracking();
      expect(h.controller.followMode, isTrue);
      h.controller.startAdjust();
      await h.emit(_offsetNorth(MockPoints.mp1, 50));
      expect(h.moves, isEmpty);
      expect(h.searches, isEmpty);
    });

    test('AC4 / TC-1.3.3: GPS ignored while manual; My location → GPS, '
        'toast, zoom 16, new 1 km search', () async {
      final h = await tracking();
      h.controller
        ..startAdjust()
        ..confirmAdjust(manual);
      h.searches.clear();

      await h.emit(_offsetNorth(MockPoints.mp1, 200));
      await h.emit(_offsetNorth(MockPoints.mp1, 400));
      expect(h.controller.userPosition, manual);
      expect(h.controller.blueDot, isNull);
      expect(h.moves, isEmpty);
      expect(h.searches, isEmpty);

      h.controller.onMyLocation();
      expect(h.usingGps, 1);
      expect(h.controller.manualPosition, isNull);
      final gps = _offsetNorth(MockPoints.mp1, 400).position;
      expect(h.controller.userPosition, gps);
      expect(h.moves.single.centre, gps);
      expect(h.moves.single.zoom, MapConstants.userZoom);
      expect(h.searches.single.trigger, SearchTrigger.myLocation);
      expect(h.controller.followMode, isTrue);
    });

    for (final (name, service, consent) in [
      ('consent declined → S1', FakeLocationService(), false),
      (
        'denied → prompt',
        FakeLocationService(requestResult: LocationPermissionStatus.denied),
        true,
      ),
      (
        'GPS off → location settings',
        FakeLocationService(serviceEnabled: false),
        true,
      ),
    ]) {
      test('AC4 / AC6 / TC-1.3.15 ($name): manual works; My location keeps '
          'it and runs the banner action, no toast', () async {
        final h = _Harness(service: service, consentGranted: consent);
        await h.start();
        h.searches.clear();
        final callsBefore = service.requestCalls;

        h.controller
          ..startAdjust()
          ..confirmAdjust(manual);
        expect(h.searches.single.point, manual); // AC6

        h.controller.onMyLocation();
        await flush();
        expect(h.controller.manualPosition, manual);
        expect(h.usingGps, 0);
        expect(h.searches, hasLength(1));
        switch (name) {
          case 'consent declined → S1':
            expect(h.reopenConsent, 1);
            expect(service.totalCalls, 0);
          case 'denied → prompt':
            expect(service.requestCalls, callsBefore + 1);
          default:
            expect(service.openLocationSettingsCalls, 1);
        }
      });
    }

    test('AC4 / TC-1.3.16: switched back without a fix → after 10 s '
        'US-1.1 AC9 (default centre + banner_no_fix)', () async {
      final h = _Harness();
      await h.start();
      await h.fireTimeout(); // noFix, default-centre search
      h.controller
        ..startAdjust()
        ..confirmAdjust(manual);
      expect(h.controller.banner, isNull); // no "adjust manually?" now
      h.searches.clear();
      h.moves.clear();

      h.controller.onMyLocation();
      expect(h.usingGps, 1);
      expect(h.controller.status, LocationStatus.locating);
      expect(h.controller.banner, isNull);
      await h.fireTimeout();

      expect(h.controller.status, LocationStatus.noFix);
      expect(h.controller.banner, MapBannerKind.noFix);
      expect(h.searches.single.point, MapConstants.defaultCentre);
      expect(h.moves.single.centre, MapConstants.defaultCentre);
    });

    test('AC4: switched back without a fix → a fix in time is the first '
        'fix', () async {
      final h = _Harness();
      await h.start();
      await h.fireTimeout();
      h.controller
        ..startAdjust()
        ..confirmAdjust(manual);
      h.searches.clear();
      h.controller.onMyLocation();
      await h.emit(MockPoints.mp4);
      expect(h.moves.last.centre, MockPoints.mp4.position);
      expect(h.moves.last.zoom, MapConstants.userZoom);
      expect(h.searches.single.trigger, SearchTrigger.firstPosition);
    });

    test('US-1.1 AC12: a late fix while manual → no camera jump, no '
        'reload; timeout while manual keeps it', () async {
      final h = _Harness();
      await h.start();
      h.controller
        ..startAdjust()
        ..confirmAdjust(manual); // before the 10 s timeout
      h.searches.clear();
      await h.fireTimeout();
      expect(h.searches, isEmpty); // no default-centre reload
      expect(h.controller.banner, isNull);
      await h.emit(MockPoints.mp1);
      expect(h.moves, isEmpty);
      expect(h.searches, isEmpty);
      expect(h.controller.userPosition, manual);
    });

    test('last-known while manual → no "Locating…", no jump', () async {
      final h = _Harness(
        service: FakeLocationService(
          lastKnown: fixAt(
            10.3460,
            107.0740,
            at: testNow.subtract(const Duration(minutes: 1)),
          ),
        ),
      );
      await h.start();
      h.controller
        ..startAdjust()
        ..confirmAdjust(manual);
      h.searches.clear();
      await h.fireTimeout();
      expect(h.controller.status, LocationStatus.lastKnown);
      expect(h.controller.showLocatingHint, isFalse);
      expect(h.moves, isEmpty);
      expect(h.searches, isEmpty);
    });

    test('AC8 / TC-1.3.18: manual outside → default-centre search, '
        'out-of-area banner; edge point is inside', () async {
      final h = await tracking();
      h.controller
        ..startAdjust()
        ..confirmAdjust(MockPoints.mp6.position);
      expect(h.searches.last.point, MapConstants.defaultCentre);
      expect(h.controller.banner, MapBannerKind.outOfArea);
      expect(h.controller.userPosition, MockPoints.mp6.position);

      const edge = LatLng(10.3000, 107.1000);
      h.controller
        ..startAdjust()
        ..confirmAdjust(edge);
      expect(h.searches.last.point, edge);
      expect(h.controller.banner, isNull);
    });

    test('low-accuracy banner not shown while manual', () async {
      final h = _Harness();
      await h.start();
      await h.emit(MockPoints.mp3LowAccuracy);
      expect(h.controller.banner, MapBannerKind.lowAccuracy);
      h.controller
        ..startAdjust()
        ..confirmAdjust(manual);
      expect(h.controller.banner, isNull);
    });
  });
}
