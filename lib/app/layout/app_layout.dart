import 'dart:convert';

import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ⭐️ VModal (modal reutilizable)
import '../widgets/modal.dart';
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
                await VModal.show(
                  title: 'Confirmar',
                  leadingIcon: const Icon(Icons.logout),
                  children: const [Text('¿Deseas cerrar sesión?')],
                  cancelText: 'Cancelar',
                  confirmText: 'Cerrar sesión',
                  onConfirm: () async {
                    try {
                      await Supabase.instance.client.auth.signOut(
                        scope: SignOutScope.global,
                      );
                      // ⭐️ Cerrar el Drawer si está abierto
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      // ⭐️ Navegar al login (el listener de auth también puede manejarlo)
                      Get.offAllNamed('/login');
                      return true; // cerrar modal
                    } catch (e) {
                      Get.snackbar(
                        'Error',
                        'No se pudo cerrar sesión: $e',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                      return false; // mantener modal abierto
                    }
                  },
                );
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
