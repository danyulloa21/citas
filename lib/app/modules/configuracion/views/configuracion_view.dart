import 'dart:convert';

import 'package:agenda_citas/app/layout/app_layout.dart';
import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ConfiguracionView extends GetView<ConfiguracionController> {
  const ConfiguracionView({super.key});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = TextEditingController(text: controller.nombreClinica);

    final nombreDraft = controller.nombreClinica.obs;
    final googleIdDraft = controller.calendarIdCtrl.text.obs;

    return AppLayout(
      title: 'Configuración',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(
            () => Column(
              spacing: 24,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      await controller.pickLogo();
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: controller.logo.isNotEmpty
                          ? MemoryImage(base64Decode(controller.logo))
                          : null,
                      child: controller.logo.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 36,
                                  color: Colors.grey[800],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Toca para agregar/editar',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),

                Row(
                  spacing: 12,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('Logo desde URL'),
                      onPressed: () {
                        final urlCtrl = TextEditingController();
                        Get.defaultDialog(
                          title: 'Logo desde URL',
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Pega la URL directa de una imagen (png/jpg/svg*).',
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: urlCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'https://tu-dominio.com/logo.png',
                                ),
                              ),
                            ],
                          ),
                          textCancel: 'Cancelar',
                          textConfirm: 'Usar',
                          onConfirm: () async {
                            Get.back();
                            await controller.setLogoFromUrl(urlCtrl.text);
                          },
                        );
                      },
                    ),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar logo'),
                      onPressed: () {
                        controller.clearLogo();
                        Get.snackbar(
                          'Logo eliminado',
                          'Se removió el logo actual.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),

                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Nombre de la clínica',
                        ),
                        onChanged: (v) => nombreDraft.value = v,
                        onSubmitted: controller.setNombre,
                      ),
                    ),
                    Obx(() {
                      final showSave =
                          nombreDraft.value.trim() !=
                          controller.nombreClinica.trim();
                      if (!showSave) return const SizedBox.shrink();
                      return ElevatedButton.icon(
                        onPressed: () {
                          controller.setNombre(nombreDraft.value.trim());
                          FocusScope.of(context).unfocus();
                          Get.snackbar(
                            'Guardado',
                            'Nombre de la clínica actualizado',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                      );
                    }),
                  ],
                ),
                Text(
                  'ID del calendario (Google Calendar ID)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.calendarIdCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText:
                              'ej: your_calendar_id@group.calendar.google.com',
                        ),
                        onChanged: (v) => googleIdDraft.value = v,
                        onSubmitted: (value) => controller.saveCalendarId(),
                      ),
                    ),

                    // Botón: pegar desde portapapeles y extraer
                    IconButton(
                      tooltip: 'Pegar URL y extraer ID',
                      icon: const Icon(Icons.paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        final text = data?.text ?? '';
                        if (text.trim().isEmpty) {
                          Get.snackbar(
                            'Portapapeles vacío',
                            'No hay texto para pegar.',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          return;
                        }
                        controller.extractAndShowCalendarId(text.trim());
                      },
                    ),

                    // Botón: abrir diálogo para pegar URL manualmente
                    IconButton(
                      tooltip: 'Pegar manualmente / Extraer desde URL',
                      icon: const Icon(Icons.link),
                      onPressed: () {
                        final urlCtrl = TextEditingController();
                        Get.defaultDialog(
                          title: 'Extraer ID desde URL',
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Pega la URL pública del calendario o el enlace embed y presiona Extraer.',
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: urlCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText:
                                      'https://.../calendar/embed?src=...',
                                ),
                              ),
                            ],
                          ),
                          textCancel: 'Cancelar',
                          textConfirm: 'Extraer',
                          onConfirm: () {
                            Get.back();
                            controller.extractAndShowCalendarId(
                              urlCtrl.text.trim(),
                            );
                          },
                        );
                      },
                    ),

                    Obx(() {
                      final showSave =
                          googleIdDraft.value.trim() !=
                          controller.calendarId.trim();
                      if (!showSave) return const SizedBox.shrink();
                      return ElevatedButton.icon(
                        onPressed: () {
                          controller.saveCalendarId();
                          googleIdDraft.value = controller.calendarIdCtrl.text
                              .trim();
                          FocusScope.of(context).unfocus();
                          Get.snackbar(
                            'Guardado',
                            'ID de calendario guardado',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                      );
                    }),
                  ],
                ),

                Obx(() {
                  final id = controller.calendarId;

                  if (id.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Sin ID guardado',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Text(
                            'ID actual: $id',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        OutlinedButton.icon(
                          onPressed: controller.clearCalendarId,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Eliminar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                SwitchListTile(
                  title: const Text('Tema oscuro'),
                  value: controller.isDark,
                  onChanged: controller.toggleTheme,
                ),

                Text('Nombre actual: ${controller.nombreClinica}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
