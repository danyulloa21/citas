import 'dart:convert';

import 'package:image_cropper/image_cropper.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agenda_citas/app/data/models/evento.dart';

import 'package:agenda_citas/app/services/google_auth_service.dart';
import 'package:http/http.dart' as http;

class ConfiguracionController extends GetxController {
  final _storage = GetStorage();
  final _nombreClinica = ''.obs;
  final _logo = ''.obs;
  final _isDark = false.obs;

  final calendarIdCtrl = TextEditingController();

  final _calendarId = ''.obs;
  final events = <Evento>[].obs;

  String get nombreClinica => _nombreClinica.value;
  String get logo => _logo.value;
  bool get isDark => _isDark.value;

  @override
  void onInit() {
    super.onInit();
    _nombreClinica.value = _storage.read('nombreClinica') ?? '';
    _logo.value = _storage.read('logo') ?? '';
    _isDark.value = _storage.read('isDark') ?? Get.isDarkMode;

    _calendarId.value = _storage.read('calendarId') ?? '';
    calendarIdCtrl.text = _calendarId.value;
  }

  void setNombre(String nombre) {
    _nombreClinica.value = nombre;
    _storage.write('nombreClinica', nombre);
  }

  void toggleTheme(bool isDark) {
    _isDark.value = isDark;
    _storage.write('isDark', isDark);
    Get.changeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  String get calendarId => _calendarId.value;

  void clearCalendarId() {
    _calendarId.value = '';
    _storage.remove('calendarId');
    calendarIdCtrl.text = '';
  }

  void saveCalendarId() {
    final id = calendarIdCtrl.text.trim();
    if (id.isEmpty) return;
    _calendarId.value = id;
    _storage.write('calendarId', id);
  }

  void _extractAndCacheCalendarId(String url) {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);

      // Intentar obtener src=... en query params (embed URLs)
      String? src = uri.queryParameters['src'];
      if (src != null && src.isNotEmpty) {
        final decoded = Uri.decodeComponent(src);
        _calendarId.value = decoded;
        _storage.write('calendarId', decoded);
        return;
      }

      // Buscar en fragmentos o en la ruta elementos que contengan '@' (calendar ids)
      final full = url;
      final reg = RegExp(r'([A-Za-z0-9%._\-]+@[^\/?&]+)');
      final m = reg.firstMatch(full);
      if (m != null) {
        final id = Uri.decodeComponent(m.group(1)!);
        _calendarId.value = id;
        _storage.write('calendarId', id);
        return;
      }

      // Si no fue posible extraer, no guardamos nada
    } catch (e) {
      // ignore parse errors
    }
  }

  /// Extrae el calendarId desde una URL, lo guarda en storage y muestra un
  /// mensaje al usuario con el resultado. Este método es público para que
  /// la UI pueda invocarlo y mostrar de inmediato el calendarId extraído.
  void extractAndShowCalendarId(String url) {
    try {
      final before = _calendarId.value;
      _extractAndCacheCalendarId(url);
      if (_calendarId.value.isNotEmpty) {
        // Actualizar campo de texto para que la UI muestre el valor
        calendarIdCtrl.text = _calendarId.value;

        Get.snackbar(
          'ID de calendario extraído',
          _calendarId.value,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        // No se pudo extraer; restaurar valor previo en el controlador
        calendarIdCtrl.text = before;
        Get.snackbar(
          'No encontrado',
          'No se pudo extraer un ID de calendario válido de la URL proporcionada.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Ocurrió un error al extraer el ID: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> loadEventsFromCalendar() async {
    // Preferir Google Calendar API si tenemos un calendarId
    final id = _calendarId.value;

    if (id.isNotEmpty) {
      // Usar Google Calendar API
      final ok = await TransparentGoogleAuthService.ensureAuthenticated();
      if (!ok) {
        Get.snackbar(
          'Error',
          'No se pudo autenticar con Google. Inicia sesión primero.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      final headers = TransparentGoogleAuthService.authHeaders;
      if (headers == null) {
        Get.snackbar(
          'Error',
          'No se encontraron headers de autenticación.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      try {
        // Queremos incluir TODO el día actual (desde 00:00) para que
        // eventos ocurridos antes de la hora actual sigan apareciendo.
        final nowLocal = DateTime.now();
        final startOfTodayLocal = DateTime(
          nowLocal.year,
          nowLocal.month,
          nowLocal.day,
        );
        final timeMin = startOfTodayLocal.toUtc().toIso8601String();
        final timeMax = startOfTodayLocal
            .add(const Duration(days: 365))
            .toUtc()
            .toIso8601String();

        final uri = Uri.https(
          'www.googleapis.com',
          '/calendar/v3/calendars/$id/events',
          {
            'singleEvents': 'true',
            'orderBy': 'startTime',
            'timeMin': timeMin,
            'timeMax': timeMax,
            'maxResults': '250',
          },
        );

        final resp = await http.get(uri, headers: headers);
        if (resp.statusCode != 200) {
          throw Exception('Google Calendar API: ${resp.statusCode}');
        }

        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?) ?? [];

        final parsed = <Evento>[];
        for (final it in items.cast<Map<String, dynamic>>()) {
          final startObj = it['start'];
          final endObj = it['end'];

          DateTime? parseDate(dynamic v) {
            if (v == null) return null;
            if (v is String) return DateTime.tryParse(v);
            if (v is Map<String, dynamic>) {
              if (v['dateTime'] != null)
                return DateTime.tryParse(v['dateTime']);
              if (v['date'] != null) return DateTime.tryParse(v['date']);
            }
            return null;
          }

          final start = parseDate(startObj);
          final end = parseDate(endObj);
          final summary = (it['summary'] as String?) ?? 'Sin título';
          final description = it['description'] as String?;
          final location = it['location'] as String?;

          if (start != null) {
            parsed.add(
              Evento(
                start: start,
                end: end,
                summary: summary,
                description: description,
                location: location,
              ),
            );
          }
        }

        events.assignAll(parsed);
        return;
      } catch (e) {
        Get.snackbar(
          'Error',
          'No se pudo cargar eventos desde Google API: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
    }
  }

  // Reemplazado: ahora hace pick + crop/resize con ImageCropper
  Future<void> pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      // 1) Abrir galería
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        return;
      }

      // 2) Abrir modal nativo de crop/resize/rotate (ImageCropper)
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar logo',
            toolbarColor: Colors.black87,
            toolbarWidgetColor: Colors.white,
          ),
          IOSUiSettings(title: 'Ajustar logo'),
        ],
      );

      // 3) Si el usuario canceló el crop, no hacemos nada
      if (cropped == null) {
        return;
      }

      // 4) Guardar resultado (base64)
      final bytes = await cropped.readAsBytes();
      final base64Image = base64Encode(bytes);
      _logo.value = base64Image;
      _storage.write('logo', base64Image);

      Get.snackbar(
        'Éxito',
        'Logo actualizado',
        snackPosition: SnackPosition.BOTTOM,
        snackStyle: SnackStyle.FLOATING,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudo seleccionar/editar la imagen. ${'$e'}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> setLogoFromUrl(String url) async {
    try {
      if (url.trim().isEmpty) {
        Get.snackbar(
          'URL vacía',
          'Ingresa una URL válida.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      final uri = Uri.parse(url.trim());
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        Get.snackbar(
          'No se pudo descargar',
          'Respuesta HTTP ${resp.statusCode}. Verifica la URL.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Validación simple de tipo de contenido
      final contentType = resp.headers['content-type'] ?? '';
      if (!(contentType.contains('image/'))) {
        Get.snackbar(
          'Contenido no válido',
          'La URL no apunta a una imagen.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      final bytes = resp.bodyBytes;
      final base64Image = base64Encode(bytes);

      _logo.value = base64Image; // ⭐️ Actualiza en memoria
      _storage.write('logo', base64Image); // ⭐️ Persiste

      Get.snackbar(
        'Éxito',
        'Logo establecido desde URL',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudo establecer el logo desde la URL. ${'$e'}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void clearLogo() {
    _logo.value = '';
    _storage.write('logo', '');
  }

  /// Elimina un evento de la lista local de eventos.
  /// Actualmente solo lo quita de la colección `events` en memoria.
  /// Si en el futuro quieres persistir o borrar en la API, extiende este método.
  void removeEvent(Evento e) {
    try {
      events.removeWhere((x) => x.start == e.start && x.summary == e.summary);
      Get.snackbar(
        'Evento eliminado',
        'El evento "${e.summary}" ha sido eliminado de la lista local.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (err) {
      Get.snackbar(
        'Error',
        'No se pudo eliminar el evento: ${err.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
