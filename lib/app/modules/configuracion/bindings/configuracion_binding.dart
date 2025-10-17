import 'package:get/get.dart';
import '../controllers/configuracion_controller.dart';

class ConfiguracionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConfiguracionController>(() => ConfiguracionController());
  }
}
