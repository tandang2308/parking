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

  @override
  String get banner_location_off => 'Định vị đang tắt';

  @override
  String get btn_turn_on => 'Bật định vị';

  @override
  String get web_unblock_title => 'Vị trí đang bị chặn';

  @override
  String get web_unblock_guide =>
      'Trang này đang bị chặn truy cập vị trí. Hãy mở cài đặt trang web của trình duyệt, cho phép Vị trí, rồi tải lại trang.';

  @override
  String get btn_ok => 'OK';

  @override
  String get hint_locating => 'Đang định vị…';

  @override
  String get banner_no_fix => 'Không lấy được vị trí của bạn — chỉnh thủ công?';

  @override
  String get btn_adjust => 'Chỉnh vị trí';

  @override
  String get out_of_area => 'Hiện ParkFinder chỉ hỗ trợ Vũng Tàu';

  @override
  String get btn_go_vung_tau => 'Đến Vũng Tàu';

  @override
  String get a11y_dismiss => 'Đóng';

  @override
  String get a11y_my_location => 'Vị trí của tôi';
}
