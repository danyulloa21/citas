// ⭐️ Nuevo archivo
import 'package:get_storage/get_storage.dart';

class CalendarCacheService {
  static const _kCalendarUrlKey = 'calendar_url';
  final GetStorage _box = GetStorage();

  String? getCalendarUrl() => _box.read<String>(_kCalendarUrlKey);

  Future<void> setCalendarUrl(String url) async {
    await _box.write(_kCalendarUrlKey, url);
  }

  Future<void> clearCalendarUrl() async {
    await _box.remove(_kCalendarUrlKey);
  }
}
