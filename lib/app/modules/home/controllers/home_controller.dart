import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:agenda_citas/app/services/google_auth_service.dart';
import 'package:get/get.dart';

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
        TransparentGoogleAuthService.isSignedIn) {
      // No await aquí para no bloquear la UI; el controlador mostrará mensajes si hay errores
      configCtrl.loadEventsFromCalendar();
    }
  }
}
