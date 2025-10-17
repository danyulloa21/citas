import 'dart:convert';

import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/auth_status_widget.dart';

class AppLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  const AppLayout({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final configController = Get.isRegistered<ConfiguracionController>()
        ? Get.find<ConfiguracionController>()
        : Get.put<ConfiguracionController>(
            ConfiguracionController(),
            permanent: true,
          );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.teal),
              child: Center(
                child: Obx(() {
                  final logoBase64 = configController.logo;
                  if (logoBase64.isNotEmpty) {
                    return Column(
                      spacing: 10,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: MemoryImage(
                            base64Decode(logoBase64),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        Text(
                          configController.nombreClinica,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Si no hay logo guardado, solo muestra el nombre
                    return Text(
                      configController.nombreClinica,
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                    );
                  }
                }),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Get.offAllNamed('/home'),
            ),
            ListTile(
              leading: const Icon(Icons.event_note),
              title: const Text('Agenda'),
              onTap: () => Get.offAllNamed('/agenda'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Configuración'),
              onTap: () => Get.offAllNamed('/config'),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(children: const [Expanded(child: AuthStatusWidget())]),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar sesión'),
              textColor: Colors.redAccent,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: Get.context!,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirmar'),
                    content: const Text('¿Deseas cerrar sesión?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Supabase.instance.client.auth.signOut(
                    scope: SignOutScope.global,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
