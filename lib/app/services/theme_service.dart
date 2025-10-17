import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeService extends GetxService {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  // Rx para reactividad
  final _isDark = false.obs;

  ThemeService() {
    _isDark.value = _loadThemeFromBox();
  }

  bool _loadThemeFromBox() => _box.read(_key) ?? false;

  ThemeMode get theme => _isDark.value ? ThemeMode.dark : ThemeMode.light;

  void switchTheme(bool isDark) {
    _isDark.value = isDark;
    _box.write(_key, isDark);
    Get.changeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
