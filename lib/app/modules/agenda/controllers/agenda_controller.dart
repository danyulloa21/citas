import 'package:agenda_citas/app/data/models/evento.dart';
import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:get/get.dart';

class AgendaController extends GetxController {
  final configCtrl = Get.find<ConfiguracionController>();

  @override
  void onInit() {
    super.onInit();
    configCtrl.loadEventsFromCalendar();
  }

  Map<DateTime, List<Evento>> groupEventsByDay(List<Evento> events) {
    final map = <DateTime, List<Evento>>{};
    for (final e in events) {
      final day = DateTime(e.start.year, e.start.month, e.start.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }
}
