// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get consent_title => 'Allow location access';

  @override
  String get consent_body =>
      'ParkFinder uses your location only while the app is open, to show parking lots near you. Your location is not stored on our servers. You can turn this off at any time in your device or browser settings.';

  @override
  String get btn_allow => 'Allow';

  @override
  String get btn_not_now => 'Not now';

  @override
  String get banner_location_needed => 'Turn on location to see lots near you';

  @override
  String get btn_enable => 'Enable';
}
