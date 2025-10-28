import 'package:agenda_citas/app/data/models/evento.dart';
import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:get/get.dart';

class AgendaController extends GetxController {
  // ⭐️ Estado de carga centralizado para el spinner en Agenda
  final RxBool isLoading = false.obs;

  final configCtrl = Get.find<ConfiguracionController>();

  @override
  void onInit() {
    super.onInit();
    // ⭐️ Carga inicial: eventos del día actual con spinner centralizado
    refreshForDay(DateTime.now());
  }

  /// ⭐️ Refresca los eventos para un día específico y controla isLoading
  Future<void> refreshForDay(DateTime day) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      await configCtrl.loadEventsForDay(day);
    } finally {
      isLoading.value = false;
    }
  }

  Map<DateTime, List<Evento>> groupEventsByDay(List<Evento> events) {
    final map = <DateTime, List<Evento>>{};
    for (final e in events) {
      final day = DateTime(e.start.year, e.start.month, e.start.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }

  Future<bool> createEventInSelectedCalendar({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
    List<String>? attendees,
    bool allDay = false,
  }) async {
    if (isLoading.value) return false;
    isLoading.value = true;
    try {
      final ok = await configCtrl.addEventToCalendar(
        summary: title,
        startLocal: start,
        endLocal: end,
        description: description,
        location: location,
        attendeesEmails: attendees,
        allDay: allDay,
      );
      // Refrescar el día del inicio del evento para ver el cambio
      await refreshForDay(DateTime(start.year, start.month, start.day));
      return ok;
    } finally {
      isLoading.value = false;
    }
  }
}
