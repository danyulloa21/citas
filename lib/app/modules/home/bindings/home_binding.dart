import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../configuracion/controllers/configuracion_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Asegurar que el ConfiguracionController esté disponible antes de crear HomeController
    if (!Get.isRegistered<ConfiguracionController>()) {
      Get.put<ConfiguracionController>(
        ConfiguracionController(),
        permanent: true,
      );
    }
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
