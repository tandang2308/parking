import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/tile_config.dart';
import 'features/consent/consent_gate.dart';
import 'features/consent/consent_record.dart';
import 'features/consent/consent_store.dart';
import 'features/location/location_controller.dart';
import 'features/location/location_service.dart';
import 'features/map/base_tile_layer.dart';
import 'features/map/map_screen.dart';
import 'l10n/generated/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ParkFinderApp(
      tileConfig: TileConfig.fromEnvironment(),
      consentStore: SharedPrefsConsentStore(),
      locationService: PlatformLocationService(),
    ),
  );
}

/// Supported locales. Vietnamese first: it is the fallback when the
/// device/browser language is neither vi nor en (Vũng Tàu pilot).
const List<Locale> kSupportedLocales = [Locale('vi'), Locale('en')];

class ParkFinderApp extends StatefulWidget {
  const ParkFinderApp({
    super.key,
    required this.tileConfig,
    required this.consentStore,
    required this.locationService,
    this.styleLoader = loadStyleFromNetwork,
    this.consentVersion = kConsentVersion,
    this.onSearchCentreChanged,
    this.clock,
    this.timerFactory,
  });

  final TileConfig tileConfig;
  final ConsentStore consentStore;
  final LocationService locationService;
  final StyleLoader styleLoader;
  final int consentVersion;

  /// BR-3 search hook (US-1.1 AC8). TODO(US-1.2): load `nearby_lots` here.
  final SearchCentreCallback? onSearchCentreChanged;

  /// Injectable for tests (AC9 timeout, last-known age).
  final DateTime Function()? clock;
  final TimerFactory? timerFactory;

  @override
  State<ParkFinderApp> createState() => _ParkFinderAppState();
}

class _ParkFinderAppState extends State<ParkFinderApp> {
  /// Session-scoped map state (e.g. dismissed banners), until app restart.
  final MapSession _session = MapSession();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Brand name, not translated.
      title: 'ParkFinder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      // Locale follows the device/browser; unsupported languages fall back
      // to the first supported locale (vi).
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ConsentGate(
        store: widget.consentStore,
        consentVersion: widget.consentVersion,
        mapBuilder: (context, access) => MapScreen(
          key: ValueKey('map-${access.allowed}'),
          tileConfig: widget.tileConfig,
          styleLoader: widget.styleLoader,
          session: _session,
          // BR-9 / D3: the map gets no location service without consent.
          locationService: access.allowed ? widget.locationService : null,
          requestPermissionOnStart: access.requestPermission,
          onReopenConsent: access.onReopenConsent,
          onSearchCentreChanged: widget.onSearchCentreChanged,
          // TODO(US-1.3): "Adjust" starts adjust mode (US-1.3 AC2).
          onAdjustRequested: null,
          clock: widget.clock,
          timerFactory: widget.timerFactory,
        ),
      ),
    );
  }
}
