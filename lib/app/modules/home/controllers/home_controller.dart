import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeController extends GetxController {
  final greeting = 'Bienvenido a'.obs;

  // Acceso al controlador de configuración
  final configCtrl = Get.find<ConfiguracionController>();

  String get fullGreeting => '${greeting.value} ${configCtrl.nombreClinica} 🐾';
  String get logo => configCtrl.logo;

  @override
  void onReady() {
    super.onReady();
    // Al entrar en la vista, sólo cargar eventos automáticamente si ya
    // estamos autenticados y existe un calendarId. No forzamos login aquí.
    if (configCtrl.calendarId.isNotEmpty &&
        Supabase.instance.client.auth.currentSession != null) {
      // No await para no bloquear la UI
      configCtrl.loadEventsFromCalendar();
    }
  }
}
