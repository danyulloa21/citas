import 'package:agenda_citas/app/modules/agenda/controllers/agenda_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:agenda_citas/app/layout/app_layout.dart';
import 'package:agenda_citas/app/data/models/evento.dart';
import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';

class AgendaView extends GetView<AgendaController> {
  final ConfiguracionController configCtrl =
      Get.find<ConfiguracionController>();
  final Rx<DateTime> selectedDay = DateTime.now().obs;
  // formato del calendario (mes o semana)
  final Rx<CalendarFormat> calendarFormat = CalendarFormat.month.obs;

  AgendaView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'Agenda',
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Toggle para cambiar vista mensual/semana
            Obx(() {
              final isMonth = calendarFormat.value == CalendarFormat.month;
              return Row(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ToggleButtons(
                    isSelected: [isMonth, !isMonth],
                    onPressed: (index) {
                      calendarFormat.value = index == 0
                          ? CalendarFormat.month
                          : CalendarFormat.week;
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('Mes'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('Semana'),
                      ),
                    ],
                  ),

                  TextButton.icon(
                    onPressed: () => configCtrl.loadEventsFromCalendar(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refrescar'),
                  ),
                ],
              );
            }),
            // Botones para refrescar / cargar

            // Calendario
            Obx(() {
              final events = configCtrl.events;
              final eventsMap = controller.groupEventsByDay(events);

              return TableCalendar<Evento>(
                firstDay: DateTime.utc(2000, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: selectedDay.value,
                calendarFormat: calendarFormat.value,
                onFormatChanged: (f) => calendarFormat.value = f,
                selectedDayPredicate: (day) =>
                    isSameDay(day, selectedDay.value),
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return eventsMap[key] ?? [];
                },
                onDaySelected: (day, focusedDay) {
                  selectedDay.value = day;
                },
                headerStyle: const HeaderStyle(formatButtonVisible: false),
                calendarStyle: const CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // Lista de eventos del día seleccionado
            Expanded(
              child: Obx(() {
                final events = configCtrl.events;
                final eventsMap = controller.groupEventsByDay(events);
                final dayKey = DateTime(
                  selectedDay.value.year,
                  selectedDay.value.month,
                  selectedDay.value.day,
                );
                final dayEvents = eventsMap[dayKey] ?? [];

                if (dayEvents.isEmpty) {
                  return const Center(
                    child: Text('No hay eventos para el día seleccionado.'),
                  );
                }

                return ListView.separated(
                  itemCount: dayEvents.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final e = dayEvents[i];
                    final start = e.start.toLocal().toString().split('.').first;
                    final end = e.end != null
                        ? ' - ${e.end!.toLocal().toString().split('.').first}'
                        : '';
                    return GestureDetector(
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar evento'),
                            content: Text('¿Deseas eliminar "${e.summary}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          configCtrl.removeEvent(e);
                        }
                      },
                      child: ListTile(
                        leading: const Icon(Icons.event_note),
                        title: Text(e.summary),
                        subtitle: Text(
                          '$start$end${e.location != null ? '\n${e.location}' : ''}',
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
