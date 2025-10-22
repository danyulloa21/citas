import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'app/routes/app_pages.dart';
import 'app/services/theme_service.dart';
import 'app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  const envFile = 'assets/.env';
  try {
    await dotenv.load(fileName: envFile);
    debugPrint('⭐️ dotenv loaded: $envFile');
  } catch (e) {
    debugPrint('⭐️ dotenv not loaded ($envFile): $e');
  }

  // Inicializar Supabase si hay variables de entorno
  final supaUrl = dotenv.env['SUPABASE_URL'];
  final supaKey = dotenv.env['SUPABASE_API_KEY'];
  if (supaUrl != null && supaKey != null) {
    try {
      await Supabase.initialize(url: supaUrl, anonKey: supaKey);
      SupabaseService.instance.client = Supabase.instance.client;
      debugPrint('✅ Supabase initialized');
    } catch (e) {
      debugPrint('⚠️ Supabase init failed: $e');
    }
  } else {
    debugPrint('⚠️ SUPABASE_URL or SUPABASE_ANON_KEY not found in env');
  }

  runApp(const VetApp());
}

class VetApp extends StatefulWidget {
  const VetApp({super.key});

  @override
  State<VetApp> createState() => _VetAppState();
}

class _VetAppState extends State<VetApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VetCitas',
        initialRoute: AppPages.initialRoute(),
        getPages: AppPages.routes,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeService.theme,
      ),
    );
  }
}
