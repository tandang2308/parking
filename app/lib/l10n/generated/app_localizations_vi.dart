// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get consent_title => 'Cho phép truy cập vị trí';

  @override
  String get consent_body =>
      'ParkFinder chỉ dùng vị trí của bạn khi bạn đang mở ứng dụng, để hiển thị các bãi xe gần bạn. Vị trí không được lưu trên máy chủ của chúng tôi. Bạn có thể tắt quyền này bất cứ lúc nào trong cài đặt của thiết bị hoặc trình duyệt.';

  @override
  String get btn_allow => 'Cho phép';

  @override
  String get btn_not_now => 'Để sau';

  @override
  String get banner_location_needed => 'Bật định vị để xem bãi xe gần bạn';

  @override
  String get btn_enable => 'Bật';
}
