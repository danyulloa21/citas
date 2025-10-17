import 'package:get/get.dart';

import '../modules/home/views/home_view.dart';
import '../modules/home/bindings/home_binding.dart';

import '../modules/agenda/views/agenda_view.dart';
import '../modules/agenda/bindings/agenda_binding.dart';

import '../modules/configuracion/views/configuracion_view.dart';
import '../modules/configuracion/bindings/configuracion_binding.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = <GetPage>[
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
}
