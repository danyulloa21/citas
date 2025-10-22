import 'dart:convert';

import 'package:agenda_citas/app/layout/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'Home',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header: avatar + clinic name (always visible)
              Obx(() {
                final logoBase64 = controller.logo;
                Widget avatar;
                if (logoBase64.isEmpty) {
                  avatar = const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.local_hospital, size: 28),
                  );
                } else {
                  try {
                    final bytes = base64Decode(logoBase64);
                    avatar = CircleAvatar(
                      radius: 40,
                      backgroundImage: MemoryImage(bytes),
                      backgroundColor: Colors.transparent,
                    );
                  } catch (e) {
                    avatar = const CircleAvatar(
                      radius: 40,
                      child: Icon(Icons.broken_image, size: 28),
                    );
                  }
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        controller.fullGreeting,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 16),

              // Authentication-aware body using Supabase session
              StreamBuilder<AuthState>(
                stream: Supabase.instance.client.auth.onAuthStateChange,
                builder: (context, snapshot) {
                  final hasSession = snapshot.hasData
                      ? snapshot.data!.session != null
                      : Supabase.instance.client.auth.currentSession != null;

                  if (!hasSession) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'No has iniciado sesión. Algunas funciones requieren acceder con tu cuenta.',
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => Get.toNamed('/login'),
                                icon: const Icon(Icons.login),
                                label: const Text('Ir a iniciar sesión'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Authenticated: show events UI
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Eventos de hoy',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: controller.configCtrl.calendarId.isEmpty
                                ? null
                                : () => controller.refreshCalendarEvents(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Actualizar'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Obx(() {
                        final config = controller.configCtrl;
                        final calendarId = config.calendarId;

                        // ⭐️ Mostrar spinner mientras se cargan los eventos
                        if (controller.isLoading.value) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (calendarId.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('No hay ID de calendario guardado.'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => Get.toNamed('/config'),
                                child: const Text(
                                  'Configurar ID de calendario',
                                ),
                              ),
                            ],
                          );
                        }

                        final evs = config.events;
                        if (evs.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('No hay eventos cargados.'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => controller.configCtrl
                                    .loadEventsFromCalendar(),
                                child: const Text('Cargar eventos'),
                              ),
                            ],
                          );
                        }

                        // Filtrar eventos que ocurren hoy (date-only)
                        final today = DateTime.now();
                        final todayKey = DateTime(
                          today.year,
                          today.month,
                          today.day,
                        );
                        final todays = evs.where((e) {
                          final s = e.start.toLocal();
                          final key = DateTime(s.year, s.month, s.day);
                          return key == todayKey;
                        }).toList()..sort((a, b) => a.start.compareTo(b.start));

                        if (todays.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('No hay eventos para hoy.'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => controller.configCtrl
                                    .loadEventsFromCalendar(),
                                child: const Text('Cargar eventos'),
                              ),
                            ],
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: todays.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, i) {
                            final e = todays[i];
                            final start = e.start
                                .toLocal()
                                .toString()
                                .split('.')
                                .first;
                            final end = e.end != null
                                ? ' - ${e.end!.toLocal().toString().split('.').first}'
                                : '';
                            return ListTile(
                              title: Text(e.summary),
                              subtitle: Text(
                                '$start$end${e.location != null ? '\n${e.location}' : ''}',
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
