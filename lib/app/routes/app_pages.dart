import 'package:get/get.dart';

import '../modules/home/views/home_view.dart';
import '../modules/home/bindings/home_binding.dart';

import '../modules/agenda/views/agenda_view.dart';
import '../modules/agenda/bindings/agenda_binding.dart';

import '../modules/configuracion/views/configuracion_view.dart';
import '../modules/configuracion/bindings/configuracion_binding.dart';

import '../modules/auth/login_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../services/supabase_service.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  // Nota: la ruta inicial se decide en runtime en main.dart

  static final routes = <GetPage>[
    GetPage(
      name: Routes.login,
      page: () => LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.agenda,
      page: () => AgendaView(),
      binding: AgendaBinding(),
    ),
    GetPage(
      name: Routes.config,
      page: () => const ConfiguracionView(),
      binding: ConfiguracionBinding(),
    ),
  ];

  static String initialRoute() {
    try {
      final user = SupabaseService.instance.client.auth.currentUser;
      return user == null ? Routes.login : Routes.home;
    } catch (_) {
      return Routes.login;
    }
  }
}
