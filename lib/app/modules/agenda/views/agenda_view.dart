import 'package:agenda_citas/app/modules/agenda/controllers/agenda_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:agenda_citas/app/layout/app_layout.dart';
import 'package:agenda_citas/app/data/models/evento.dart';
import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:agenda_citas/app/widgets/modal.dart';

class AgendaView extends GetView<AgendaController> {
  final ConfiguracionController configCtrl =
      Get.find<ConfiguracionController>();
  final Rx<DateTime> selectedDay = DateTime.now().obs;
  // formato del calendario (mes o semana)
  final Rx<CalendarFormat> calendarFormat = CalendarFormat.month.obs;

  Future<void> _openCreateEventModal(BuildContext context) async {
    final allDayVN = ValueNotifier<bool>(false);
    final startVN = ValueNotifier<TimeOfDay>(
      const TimeOfDay(hour: 9, minute: 0),
    );
    final endVN = ValueNotifier<TimeOfDay>(
      const TimeOfDay(hour: 10, minute: 0),
    );

    // Controladores
    final titleCtrl = TextEditingController(),
        locationCtrl = TextEditingController(),
        descriptionCtrl = TextEditingController(),
        attendeesCtrl = TextEditingController();

    // Valores iniciales: hoy seleccionado 09:00 - 10:00
    DateTime day = DateTime(
      selectedDay.value.year,
      selectedDay.value.month,
      selectedDay.value.day,
    );

    DateTime toDateTime(DateTime base, TimeOfDay t) =>
        DateTime(base.year, base.month, base.day, t.hour, t.minute);

    Future<void> pickStartTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: startVN.value,
      );
      if (picked != null) startVN.value = picked;
    }

    Future<void> pickEndTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: endVN.value,
      );
      if (picked != null) endVN.value = picked;
    }

    await VModal.show(
      title: 'Nuevo evento',
      leadingIcon: const Icon(Icons.event_available),
      confirmText: 'Crear',
      children: [
        TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Título *',
            hintText: 'Ej. Consulta con paciente',
          ),
          textInputAction: TextInputAction.next,
        ),

        Row(
          children: [
            Expanded(
              child: Text(
                'Día: ${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: allDayVN,
              builder: (_, allDay, __) =>
                  Switch(value: allDay, onChanged: (v) => allDayVN.value = v),
            ),

            const Text('Todo el día'),
          ],
        ),

        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: allDayVN,
                builder: (_, allDay, __) => OutlinedButton(
                  onPressed: allDay
                      ? null
                      : () async {
                          await pickStartTime();
                        },
                  child: ValueListenableBuilder<TimeOfDay>(
                    valueListenable: startVN,
                    builder: (_, t, __) => Text(
                      'Inicio: ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: allDayVN,
                builder: (_, allDay, __) => OutlinedButton(
                  onPressed: allDay
                      ? null
                      : () async {
                          await pickEndTime();
                        },
                  child: ValueListenableBuilder<TimeOfDay>(
                    valueListenable: endVN,
                    builder: (_, t, __) => Text(
                      'Fin: ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        TextField(
          controller: locationCtrl,
          decoration: const InputDecoration(
            labelText: 'Ubicación',
            hintText: 'Ej. Clínica Central, consultorio 2',
          ),
          textInputAction: TextInputAction.next,
        ),

        TextField(
          controller: attendeesCtrl,
          decoration: const InputDecoration(
            labelText: 'Invitados (emails, separados por coma)',
          ),
          textInputAction: TextInputAction.next,
        ),

        TextField(
          controller: descriptionCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Descripción'),
        ),
      ],
      onConfirm: () async {
        final title = titleCtrl.text.trim();
        if (title.isEmpty) {
          Get.snackbar(
            'Falta título',
            'Ingresa un título para el evento.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return false; // no cerrar
        }

        DateTime start;
        DateTime end;
        if (allDayVN.value) {
          start = day;
          end = day.add(const Duration(days: 1));
        } else {
          start = toDateTime(day, startVN.value);
          end = toDateTime(day, endVN.value);
          if (!end.isAfter(start)) {
            Get.snackbar(
              'Rango inválido',
              'La hora de fin debe ser mayor a la de inicio.',
              snackPosition: SnackPosition.BOTTOM,
            );
            return false;
          }
        }

        final attendees = attendeesCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final ok = await controller.createEventInSelectedCalendar(
          title: title,
          start: start,
          end: end,
          description: descriptionCtrl.text.trim().isEmpty
              ? null
              : descriptionCtrl.text.trim(),
          location: locationCtrl.text.trim().isEmpty
              ? null
              : locationCtrl.text.trim(),
          attendees: attendees.isEmpty ? null : attendees,
          allDay: allDayVN.value,
        );
        return ok; // si true, el VModal cierra
      },
      onDismiss: () {
        // Limpieza simple de controllers
        titleCtrl.dispose();
        locationCtrl.dispose();
        descriptionCtrl.dispose();
        attendeesCtrl.dispose();

        // ⭐️ Dispose de notifiers locales
        allDayVN.dispose();
        startVN.dispose();
        endVN.dispose();
      },
    );
  }

  AgendaView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'Agenda',
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Toggle para cambiar vista mensual/semana
                Row(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Obx(() {
                      final isMonth =
                          calendarFormat.value == CalendarFormat.month;
                      return ToggleButtons(
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
                      );
                    }),
                    IconButton(
                      tooltip: 'Refrescar día',
                      icon: const Icon(Icons.refresh),
                      onPressed: () async =>
                          controller.refreshForDay(selectedDay.value),
                    ),
                    IconButton(
                      tooltip: 'Agregar evento',
                      icon: const Icon(Icons.add),
                      onPressed: () => _openCreateEventModal(context),
                    ),
                  ],
                ),
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
                    onDaySelected: (day, focusedDay) async {
                      selectedDay.value = day;
                      await controller.refreshForDay(day);
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

                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }

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
                        final start = e.start
                            .toLocal()
                            .toString()
                            .split('.')
                            .first;
                        final end = e.end != null
                            ? ' - ${e.end!.toLocal().toString().split('.').first}'
                            : '';
                        return GestureDetector(
                          onLongPress: () async {
                            await VModal.show(
                              title: 'Eliminar evento',
                              leadingIcon: const Icon(Icons.event),
                              children: [
                                Text('¿Deseas eliminar "${e.summary}"?'),
                              ],
                              cancelText: 'Cancelar',
                              confirmText: 'Eliminar',
                              onConfirm: () async {
                                configCtrl.removeEvent(e);
                                return true; // cerrar modal
                              },
                            );
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
        ],
      ),
    );
  }
}
