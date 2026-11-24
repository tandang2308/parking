import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/tile_config.dart';
import 'features/consent/consent_gate.dart';
import 'features/consent/consent_record.dart';
import 'features/consent/consent_store.dart';
import 'features/location/location_permission_service.dart';
import 'features/map/base_tile_layer.dart';
import 'features/map/location_needed_banner.dart';
import 'features/map/map_screen.dart';
import 'l10n/generated/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ParkFinderApp(
      tileConfig: TileConfig.fromEnvironment(),
      consentStore: SharedPrefsConsentStore(),
      permissionService: const PlatformLocationPermissionService(),
    ),
  );
}

/// Supported locales. Vietnamese first: it is the fallback when the
/// device/browser language is neither vi nor en (Vũng Tàu pilot).
const List<Locale> kSupportedLocales = [Locale('vi'), Locale('en')];

class ParkFinderApp extends StatelessWidget {
  const ParkFinderApp({
    super.key,
    required this.tileConfig,
    required this.consentStore,
    required this.permissionService,
    this.styleLoader = loadStyleFromNetwork,
    this.consentVersion = kConsentVersion,
  });

  final TileConfig tileConfig;
  final ConsentStore consentStore;
  final LocationPermissionService permissionService;
  final StyleLoader styleLoader;
  final int consentVersion;

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
        store: consentStore,
        permissionService: permissionService,
        consentVersion: consentVersion,
        mapBuilder: (context, onEnableLocation) => MapScreen(
          tileConfig: tileConfig,
          styleLoader: styleLoader,
          banner: onEnableLocation == null
              ? null
              : LocationNeededBanner(onEnable: onEnableLocation),
        ),
      ),
    );
  }
}
