import 'package:agenda_citas/app/services/calendar_service.dart';
import 'package:agenda_citas/app/services/google_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'app/routes/app_pages.dart';
import 'app/services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put<CalendarCacheService>(CalendarCacheService(), permanent: true);

  // ⭐️ Carga única de variables de entorno desde assets/.env para TODAS las plataformas
  const envFile = 'assets/.env';
  try {
    await dotenv.load(fileName: envFile); // ⭐️
    debugPrint('⭐️ dotenv loaded: $envFile');
  } catch (e) {
    debugPrint('⭐️ dotenv not loaded ($envFile): $e');
  }

  try {
    final res = await TransparentGoogleAuthService.initializeTransparentAuth();
    if (res) {
      print('✅ Google Auth initialized successfully');
    } else {
      print('⚠️ Google Auth initialization failed or was cancelled');
    }
  } catch (e) {
    print('Error initializing Google Auth: $e');
  }

  runApp(const VetApp());
}

class VetApp extends StatelessWidget {
  const VetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VetCitas',
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeService.theme,
      ),
    );
  }
}
