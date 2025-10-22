import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeController extends GetxController {
  final greeting = 'Bienvenido a'.obs;
  final isLoading = false.obs;

  // Acceso al controlador de configuración
  final configCtrl = Get.find<ConfiguracionController>();

  String get fullGreeting => '${greeting.value} ${configCtrl.nombreClinica} 🐾';
  String get logo => configCtrl.logo;

  @override
  void onReady() {
    super.onReady();
    // Si hay sesión activa, siempre pedimos/confirmamos calendario
    // y luego cargamos eventos. No forzamos login desde aquí.
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    if (!hasSession) return;

    // No 'await' para no bloquear la UI; el ConfiguracionController muestra spinner.
    isLoading.value = true;
    refreshCalendarEvents().whenComplete(() => isLoading.value = false);
  }

  /// Permite refrescar manualmente: pide/valida calendario y luego carga eventos
  Future<void> refreshCalendarEvents() async {
    if (Supabase.instance.client.auth.currentSession == null) return;

    isLoading.value = true;
    try {
      await configCtrl.loadEventsFromCalendar();
    } finally {
      isLoading.value = false;
    }
  }
}
