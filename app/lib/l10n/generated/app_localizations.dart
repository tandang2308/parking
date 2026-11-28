import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// SPEC-001 §6, US-1.4 AC2: title of consent screen S1.
  ///
  /// In en, this message translates to:
  /// **'Allow location access'**
  String get consent_title;

  /// SPEC-001 §6, US-1.4 AC2: minimal privacy notice on S1.
  ///
  /// In en, this message translates to:
  /// **'ParkFinder uses your location only while the app is open, to show parking lots near you. Your location is not stored on our servers. You can turn this off at any time in your device or browser settings.'**
  String get consent_body;

  /// SPEC-001 §6, US-1.4 AC3: consent button.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get btn_allow;

  /// SPEC-001 §6, US-1.4 AC4: decline button.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get btn_not_now;

  /// SPEC-001 §6, US-1.1 AC3: map banner when location is not used.
  ///
  /// In en, this message translates to:
  /// **'Turn on location to see lots near you'**
  String get banner_location_needed;

  /// SPEC-001 §6, US-1.1 AC3–AC5: banner action (reopens S1 after a decline, re-requests the permission, or opens settings / the Web unblock guide).
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get btn_enable;

  /// SPEC-001 §6, US-1.1 AC6: banner when device location services are off (Android).
  ///
  /// In en, this message translates to:
  /// **'Location is off'**
  String get banner_location_off;

  /// SPEC-001 §6, US-1.1 AC6: opens the Android location settings.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get btn_turn_on;

  /// SPEC-001 §6, US-1.1 AC5: Web unblock guide title.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked'**
  String get web_unblock_title;

  /// SPEC-001 §6, US-1.1 AC5: Web unblock guide text.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for this site. Open your browser\'s site settings, allow Location, then reload the page.'**
  String get web_unblock_guide;

  /// SPEC-001 §6: closes the Web unblock guide.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get btn_ok;

  /// SPEC-001 §6, US-1.1 AC9: hint while a last-known position is shown.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get hint_locating;

  /// SPEC-001 §6, US-1.1 AC9: banner after the 10 s timeout without any position.
  ///
  /// In en, this message translates to:
  /// **'Can\'t get your location — adjust manually?'**
  String get banner_no_fix;

  /// SPEC-001 §6, US-1.1 AC9 / US-1.3 AC1–AC2: starts adjust mode (no-fix and low-accuracy banners).
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get btn_adjust;

  /// SPEC-001 §6, US-1.1 AC10: banner when the user is outside the service area.
  ///
  /// In en, this message translates to:
  /// **'ParkFinder currently covers Vũng Tàu only'**
  String get out_of_area;

  /// SPEC-001 §6, US-1.1 AC10: moves the camera to the default centre.
  ///
  /// In en, this message translates to:
  /// **'Go to Vũng Tàu'**
  String get btn_go_vung_tau;

  /// SPEC-001 §6, NFR-8: semantics label of a banner close (×) action.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get a11y_dismiss;

  /// SPEC-001 §6, NFR-8, US-1.1 AC8: label of the "My location" button.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get a11y_my_location;

  /// SPEC-001 §6, US-1.2 AC6: chip that loads lots around the map centre.
  ///
  /// In en, this message translates to:
  /// **'Search this area'**
  String get btn_search_area;

  /// SPEC-001 §6, US-1.2 AC4: empty state of a position-based search at 1 km.
  ///
  /// In en, this message translates to:
  /// **'No parking lots within {km} km'**
  String empty_radius(int km);

  /// SPEC-001 §6, US-1.2 AC4: repeats the current search at 3 km.
  ///
  /// In en, this message translates to:
  /// **'Expand to {km} km'**
  String btn_expand(int km);

  /// SPEC-001 §6, US-1.2 AC4: still empty after expanding.
  ///
  /// In en, this message translates to:
  /// **'No parking lots found nearby yet'**
  String get empty_none;

  /// SPEC-001 §6, US-1.2 AC4: "Search this area" returned 0 lots.
  ///
  /// In en, this message translates to:
  /// **'No parking lots in this area'**
  String get empty_area;

  /// SPEC-001 §6, US-1.2 AC5: error/offline banner.
  ///
  /// In en, this message translates to:
  /// **'Can\'t load parking lots'**
  String get error_load;

  /// SPEC-001 §6, US-1.2 AC5: repeats the last request.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get btn_retry;

  /// SPEC-001 §6, US-1.2 AC9 ({n} = 50).
  ///
  /// In en, this message translates to:
  /// **'Showing nearest {n} — zoom in to see more'**
  String hint_cap(int n);

  /// SPEC-001 §6, BR-15: distance below 1000 m (rounded to 10 m).
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distance_m(int m);

  /// SPEC-001 §6, BR-15: distance in km, one decimal, already formatted with the locale decimal separator.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distance_km(String km);

  /// SPEC-001 §6, US-1.2 AC8 card.
  ///
  /// In en, this message translates to:
  /// **'Motorbike'**
  String get vehicle_motorbike;

  /// SPEC-001 §6, US-1.2 AC8 card.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get vehicle_car;

  /// SPEC-001 §6, NFR-8: lot pin semantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {types}'**
  String a11y_pin(String name, String types);

  /// SPEC-001 §6, NFR-8: cluster semantics.
  ///
  /// In en, this message translates to:
  /// **'{count} parking lots'**
  String a11y_cluster(int count);

  /// SPEC-001 §6, US-1.3 AC1: banner on a low-accuracy fix (BR-7), with Adjust and ×.
  ///
  /// In en, this message translates to:
  /// **'Your location may be inaccurate'**
  String get banner_low_accuracy;

  /// SPEC-001 §6, US-1.3 AC3: confirms the manual position under the crosshair.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get btn_confirm;

  /// SPEC-001 §6, US-1.3 AC5: leaves adjust mode without changes.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btn_cancel;

  /// SPEC-001 §6, US-1.3 AC2: overflow menu item that starts adjust mode.
  ///
  /// In en, this message translates to:
  /// **'Set my position'**
  String get menu_set_position;

  /// SPEC-001 §6, US-1.3 AC2: hint shown in adjust mode.
  ///
  /// In en, this message translates to:
  /// **'Move the map to your exact position'**
  String get hint_adjust;

  /// SPEC-001 §6, US-1.3 AC4: toast when "My location" switches from the manual position back to GPS.
  ///
  /// In en, this message translates to:
  /// **'Using GPS location'**
  String get toast_using_gps;

  /// SPEC-001 §6, NFR-8, US-1.3 AC3: semantics label of the manual position marker.
  ///
  /// In en, this message translates to:
  /// **'Your position (set manually)'**
  String get a11y_manual_marker;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
