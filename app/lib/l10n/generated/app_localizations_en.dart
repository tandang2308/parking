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

  @override
  String get banner_location_off => 'Location is off';

  @override
  String get btn_turn_on => 'Turn on';

  @override
  String get web_unblock_title => 'Location is blocked';

  @override
  String get web_unblock_guide =>
      'Location is blocked for this site. Open your browser\'s site settings, allow Location, then reload the page.';

  @override
  String get btn_ok => 'OK';

  @override
  String get hint_locating => 'Locating…';

  @override
  String get banner_no_fix => 'Can\'t get your location — adjust manually?';

  @override
  String get btn_adjust => 'Adjust';

  @override
  String get out_of_area => 'ParkFinder currently covers Vũng Tàu only';

  @override
  String get btn_go_vung_tau => 'Go to Vũng Tàu';

  @override
  String get a11y_dismiss => 'Dismiss';

  @override
  String get a11y_my_location => 'My location';

  @override
  String get btn_search_area => 'Search this area';

  @override
  String empty_radius(int km) {
    return 'No parking lots within $km km';
  }

  @override
  String btn_expand(int km) {
    return 'Expand to $km km';
  }

  @override
  String get empty_none => 'No parking lots found nearby yet';

  @override
  String get empty_area => 'No parking lots in this area';

  @override
  String get error_load => 'Can\'t load parking lots';

  @override
  String get btn_retry => 'Retry';

  @override
  String hint_cap(int n) {
    return 'Showing nearest $n — zoom in to see more';
  }

  @override
  String distance_m(int m) {
    return '$m m';
  }

  @override
  String distance_km(String km) {
    return '$km km';
  }

  @override
  String get vehicle_motorbike => 'Motorbike';

  @override
  String get vehicle_car => 'Car';

  @override
  String a11y_pin(String name, String types) {
    return '$name, $types';
  }

  @override
  String a11y_cluster(int count) {
    return '$count parking lots';
  }

  @override
  String get banner_low_accuracy => 'Your location may be inaccurate';

  @override
  String get btn_confirm => 'Confirm';

  @override
  String get btn_cancel => 'Cancel';

  @override
  String get menu_set_position => 'Set my position';

  @override
  String get hint_adjust => 'Move the map to your exact position';

  @override
  String get toast_using_gps => 'Using GPS location';

  @override
  String get a11y_manual_marker => 'Your position (set manually)';
}
