import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase/supabase.dart';

import 'config/supabase_config.dart';
import 'config/tile_config.dart';
import 'features/consent/consent_gate.dart';
import 'features/consent/consent_record.dart';
import 'features/consent/consent_store.dart';
import 'features/location/location_controller.dart';
import 'features/location/location_service.dart';
import 'features/lots/connectivity_monitor.dart';
import 'features/lots/lot_placeholder_screen.dart';
import 'features/lots/lots_repository.dart';
import 'features/lots/parking_lot.dart';
import 'features/lots/supabase_lots_repository.dart';
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
      lotsRepository: createLotsRepository(SupabaseConfig.fromEnvironment()),
      connectivity: createPlatformConnectivityMonitor(),
    ),
  );
}

/// US-1.2: Supabase `nearby_lots` when `SUPABASE_URL` / `SUPABASE_ANON_KEY`
/// are defined; otherwise the app still starts and lot loading shows the
/// error banner (AC5).
///
/// Uses the pure-Dart `supabase` package (MIT; no Flutter plugins, so no
/// non-permissive platform dependencies). The app has no sign-in yet, so
/// no session storage or deep-link handling is needed.
LotsRepository createLotsRepository(SupabaseConfig config) {
  if (!config.isConfigured) {
    debugPrint('Supabase not configured: lots cannot be loaded.');
    return const UnconfiguredLotsRepository();
  }
  return SupabaseLotsRepository(
    SupabaseClient(
      config.normalizedUrl,
      config.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
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
    required this.lotsRepository,
    this.connectivity,
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

  /// `nearby_lots` source (US-1.2).
  final LotsRepository lotsRepository;

  /// Offline → online events for the single auto retry (US-1.2 AC5).
  final ConnectivityMonitor? connectivity;

  /// Observer of the BR-3 search triggers (US-1.1 AC8; used by tests).
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

  /// US-1.2 AC8: `/lot/:id` (placeholder until US-3.1).
  Route<void>? _onGenerateRoute(RouteSettings settings) {
    final id = LotPlaceholderScreen.idFromRoute(settings.name);
    if (id == null) return null;
    final args = settings.arguments;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => LotPlaceholderScreen(
        lotId: id,
        lot: args is ParkingLot && args.id == id ? args : null,
      ),
    );
  }

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
      onGenerateRoute: _onGenerateRoute,
      home: ConsentGate(
        store: widget.consentStore,
        consentVersion: widget.consentVersion,
        mapBuilder: (context, access) => MapScreen(
          key: ValueKey('map-${access.allowed}'),
          tileConfig: widget.tileConfig,
          styleLoader: widget.styleLoader,
          session: _session,
          lotsRepository: widget.lotsRepository,
          connectivity: widget.connectivity,
          // BR-9 / D3: the map gets no location service without consent.
          locationService: access.allowed ? widget.locationService : null,
          requestPermissionOnStart: access.requestPermission,
          onReopenConsent: access.onReopenConsent,
          onSearchCentreChanged: widget.onSearchCentreChanged,
          clock: widget.clock,
          timerFactory: widget.timerFactory,
        ),
      ),
    );
  }
}
