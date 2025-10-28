import 'dart:convert';

import 'package:agenda_citas/app/services/google_calendar_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:agenda_citas/app/widgets/modal.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agenda_citas/app/data/models/evento.dart';

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

    // Sesión sin persistencia de calendarId
    _calendarId.value = '';
    calendarIdCtrl.text = '';
  }

  void setNombre(String nombre) {
    _nombreClinica.value = nombre;
    _storage.write('nombreClinica', nombre);
  }

  String? get googleAccessToken =>
      Supabase.instance.client.auth.currentSession?.providerToken;

  String? requireGoogleAccessToken({bool silent = false}) {
    final t = googleAccessToken;
    if (t == null || t.isEmpty) {
      if (!silent) {
        Get.snackbar(
          'Autenticación requerida',
          'No se encontró un access token de Google en la sesión. Inicia sesión nuevamente con permisos de Calendar.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return null;
    }
    return t;
  }

  void toggleTheme(bool isDark) {
    _isDark.value = isDark;
    _storage.write('isDark', isDark);
    Get.changeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  String get calendarId => _calendarId.value;

  void clearCalendarId() {
    _calendarId.value = '';
    calendarIdCtrl.text = '';
  }

  void saveCalendarId() {
    final id = calendarIdCtrl.text.trim();
    if (id.isEmpty) return;
    _calendarId.value = id; // Solo en memoria para la sesión actual
  }

  void _extractAndCacheCalendarId(String url) {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);

      // Intentar obtener src=... en query params (embed URLs)
      String? src = uri.queryParameters['src'];
      if (src != null && src.isNotEmpty) {
        final decoded = Uri.decodeComponent(src);
        _calendarId.value = decoded; // no persistimos en almacenamiento
        return;
      }

      // Buscar en fragmentos o en la ruta elementos que contengan '@' (calendar ids)
      final full = url;
      final reg = RegExp(r'([A-Za-z0-9%._\-]+@[^\/?&]+)');
      final m = reg.firstMatch(full);
      if (m != null) {
        final id = Uri.decodeComponent(m.group(1)!);
        _calendarId.value = id; // no persistimos en almacenamiento
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
    await loadEventsForDay(DateTime.now()); // hoy
  }

  Future<void> loadEventsForDay(DateTime dayLocal) async {
    final startOfDay = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    await _loadEventsInRange(startOfDay, endOfDay);
  }

  Future<void> _loadEventsInRange(
    DateTime startLocal,
    DateTime endLocal,
  ) async {
    // 1) Asegura que exista un calendarId seleccionado para esta sesión
    var id = _calendarId.value.trim();
    if (id.isEmpty) {
      await ensureCalendarId();
      id = _calendarId.value.trim();
      if (id.isEmpty) {
        Get.snackbar(
          'Calendario',
          'Debes seleccionar un calendario para cargar eventos.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }
    }

    // 2) Obtén el access token de Google desde la sesión de Supabase (requiere scope calendar.readonly)
    final token = requireGoogleAccessToken();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      // 3) Define ventana de tiempo: desde hoy (00:00 local) hasta +365 días
      final timeMin = startLocal.toUtc().toIso8601String();
      final timeMax = endLocal.toUtc().toIso8601String();
      // 4) Llama Google Calendar API (Events: list)
      final uri =
          Uri.https('www.googleapis.com', '/calendar/v3/calendars/$id/events', {
            'singleEvents': 'true',
            'orderBy': 'startTime',
            'timeMin': timeMin,
            'timeMax': timeMax,
            'maxResults': '250',
            'showDeleted': 'false',
          });

      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode != 200) {
        throw Exception(
          'Google Calendar API respondió ${resp.statusCode}: ${resp.body}',
        );
      }

      // 5) Parsear respuesta a lista de Evento
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? const [];

      DateTime? parseDate(dynamic v) {
        if (v == null) return null;
        if (v is String) return DateTime.tryParse(v);
        if (v is Map<String, dynamic>) {
          // All-day events traen 'date'; eventos con hora traen 'dateTime'
          if (v['dateTime'] != null) return DateTime.tryParse(v['dateTime']);
          if (v['date'] != null) return DateTime.tryParse(v['date']);
        }
        return null;
      }

      final parsed = <Evento>[];
      for (final it in items.cast<Map<String, dynamic>>()) {
        final startObj = it['start'];
        final endObj = it['end'];
        final start = parseDate(startObj);
        final end = parseDate(endObj);

        if (start == null) continue; // sin inicio, se ignora

        final summary = (it['summary'] as String?) ?? 'Sin título';
        final description = it['description'] as String?;
        final location = it['location'] as String?;

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

      // 6) Actualiza la lista observable
      events.assignAll(parsed);
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudo cargar eventos: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// ⭐️ Crea un evento en el calendario actualmente seleccionado (solo sesión)
  /// Devuelve true si Google Calendar confirmó la creación.
  Future<bool> addEventToCalendar({
    required String summary,
    required DateTime startLocal,
    required DateTime endLocal,
    String? description,
    String? location,
    List<String>? attendeesEmails,
    bool allDay = false,
  }) async {
    try {
      // 1) Asegurar calendarId
      var id = _calendarId.value.trim();
      if (id.isEmpty) {
        await ensureCalendarId();
        id = _calendarId.value.trim();
        if (id.isEmpty) {
          Get.snackbar(
            'Calendario',
            'Debes seleccionar un calendario antes de crear eventos.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return false;
        }
      }

      // 2) Token de Google
      final token = requireGoogleAccessToken();
      if (token == null || token.isEmpty) return false;

      // 3) Construir payload
      Map<String, dynamic> startJson;
      Map<String, dynamic> endJson;
      if (allDay) {
        // Evento de todo el día usa 'date' sin hora (YYYY-MM-DD)
        final sDate = DateTime(
          startLocal.year,
          startLocal.month,
          startLocal.day,
        );
        final eDate = DateTime(endLocal.year, endLocal.month, endLocal.day);
        startJson = {'date': sDate.toIso8601String().substring(0, 10)};
        endJson = {'date': eDate.toIso8601String().substring(0, 10)};
      } else {
        // Evento con hora usa 'dateTime' en RFC3339 (usamos UTC)
        startJson = {'dateTime': startLocal.toUtc().toIso8601String()};
        endJson = {'dateTime': endLocal.toUtc().toIso8601String()};
      }

      final body = <String, dynamic>{
        'summary': summary,
        'start': startJson,
        'end': endJson,
        if (description != null && description.trim().isNotEmpty)
          'description': description,
        if (location != null && location.trim().isNotEmpty)
          'location': location,
        if (attendeesEmails != null && attendeesEmails.isNotEmpty)
          'attendees': attendeesEmails.map((e) => {'email': e}).toList(),
      };

      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/$id/events',
      );

      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw Exception(
          'Creación fallida (HTTP ${resp.statusCode}): ${resp.body}',
        );
      }

      // 4) Actualizar lista local para reflejo inmediato
      final newEvt = Evento(
        start: startLocal,
        end: endLocal,
        summary: summary,
        description: description,
        location: location,
      );
      events.add(newEvt);

      Get.snackbar(
        'Evento creado',
        '"$summary" agregado a tu calendario.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudo crear el evento: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  // ⭐️ Llama esto después de login (o al abrir Home) para auto-seleccionar ID
  Future<void> ensureCalendarId() async {
    // Siempre solicitar selección de calendario al iniciar sesión (sin persistir)
    _calendarId.value = '';
    calendarIdCtrl.text = '';

    try {
      final items = await GoogleCalendarService.listCalendars();
      if (items.isEmpty) {
        Get.snackbar(
          'Calendario',
          'No se encontraron calendarios en tu cuenta',
        );
        return;
      }

      // Normaliza items -> {id, summary, primary}
      final options = items
          .map<Map<String, dynamic>>(
            (c) => {
              'id': (c['id'] as String?) ?? '',
              'summary':
                  (c['summary'] as String?) ??
                  (c['id'] as String? ?? 'Sin nombre'),
              'primary': c['primary'] == true,
            },
          )
          .where((m) => (m['id'] as String).isNotEmpty)
          .toList();

      if (options.isEmpty) {
        Get.snackbar(
          'Calendario',
          'No se pudo determinar ningún calendario válido',
        );
        return;
      }

      // Siempre abrir picker para seleccionar calendario
      final String? chosenId = await _pickCalendarId(options);

      if (chosenId == null || chosenId.isEmpty) {
        // Usuario canceló el diálogo o no eligió
        Get.snackbar('Calendario', 'Selección cancelada');
        return;
      }

      // Actualiza sólo en memoria, no persiste
      _calendarId.value = chosenId; // solo en memoria durante esta sesión
      calendarIdCtrl.text = chosenId;
      Get.snackbar('Calendario', 'Calendario seleccionado');
    } catch (e) {
      Get.snackbar('Calendario', 'No se pudo configurar automáticamente: $e');
    }
  }

  Future<String?> _pickCalendarId(List<Map<String, dynamic>> options) async {
    // Usamos VModal.show para renderizar la lista de calendarios.
    // Al tocar una opción, cerramos el modal devolviendo el id seleccionado.
    return VModal.show<String>(
      title: 'Selecciona tu calendario',
      confirmText: 'Cerrar',
      canClose: () =>
          _calendarId.value.isNotEmpty, // bloquea cierre hasta seleccionar
      children: [
        ...options.map((opt) {
          final isPrimary = (opt['primary'] == true);
          final id = opt['id'] as String;
          final summary = opt['summary'] as String;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            onTap: () {
              _calendarId.value = id; // marca selección para canClose
              VModal.close<String>(result: id);
            },
            leading: isPrimary
                ? const Icon(Icons.star)
                : const SizedBox(width: 24),
            title: Text(
              summary,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              id,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
          );
        }),
      ],
      onConfirm: () async => true,
      showCancel: false,
      leadingIcon: const Icon(Icons.event),
    );
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

  /// Elimina un evento también en Google Calendar usando la API
  /// 1) Busca el eventId real con una consulta acotada por tiempo y título
  /// 2) Envía DELETE a /calendars/{calendarId}/events/{eventId}
  /// 3) Si el borrado en API es exitoso (204/200/410), lo quita de la lista local
  Future<void> removeEvent(Evento e) async {
    try {
      // Asegurar calendarId seleccionado
      var id = _calendarId.value.trim();
      if (id.isEmpty) {
        await ensureCalendarId();
        id = _calendarId.value.trim();
        if (id.isEmpty) {
          Get.snackbar(
            'Calendario',
            'Debes seleccionar un calendario para eliminar eventos.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return;
        }
      }

      // Access token de Google desde la sesión de Supabase
      final token = requireGoogleAccessToken();
      if (token == null || token.isEmpty) {
        return;
      }

      // ===== Paso 1: localizar el eventId real =====
      // Acotamos búsqueda por tiempo en torno al inicio del evento
      final start = e.start.toUtc();
      final timeMin = start
          .subtract(const Duration(hours: 12))
          .toIso8601String();
      final timeMax = start.add(const Duration(hours: 12)).toIso8601String();

      final listUri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/$id/events',
        {
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'timeMin': timeMin,
          'timeMax': timeMax,
          'maxResults': '50',
          'q': e.summary, // filtra por título similar
        },
      );

      final listResp = await http.get(
        listUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (listResp.statusCode != 200) {
        throw Exception(
          'No se pudo localizar el evento (HTTP ${listResp.statusCode}): ${listResp.body}',
        );
      }

      DateTime? parseDate(dynamic v) {
        if (v == null) return null;
        if (v is String) return DateTime.tryParse(v);
        if (v is Map<String, dynamic>) {
          if (v['dateTime'] != null) return DateTime.tryParse(v['dateTime']);
          if (v['date'] != null) return DateTime.tryParse(v['date']);
        }
        return null;
      }

      String? eventId;
      final listData = jsonDecode(listResp.body) as Map<String, dynamic>;
      final items = (listData['items'] as List<dynamic>?) ?? const [];

      // Elegimos el primero que coincida por título y con hora de inicio cercana
      for (final it in items.cast<Map<String, dynamic>>()) {
        final summary = (it['summary'] as String?) ?? '';
        final startObj = it['start'];
        final apiStart = parseDate(startObj)?.toUtc();
        if (summary.trim() != e.summary.trim() || apiStart == null) continue;
        final diff = apiStart.difference(start.toUtc()).abs();
        if (diff <= const Duration(minutes: 10)) {
          // tolerancia
          eventId = it['id'] as String?;
          break;
        }
      }

      if (eventId == null) {
        // No se localizó con tolerancia estrecha; como fallback, tomar el primero por título
        for (final it in items.cast<Map<String, dynamic>>()) {
          final summary = (it['summary'] as String?) ?? '';
          if (summary.trim() == e.summary.trim()) {
            eventId = it['id'] as String?;
            break;
          }
        }
      }

      if (eventId == null) {
        Get.snackbar(
          'No encontrado',
          'No se pudo localizar el evento en Google Calendar para eliminarlo.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }

      // ===== Paso 2: DELETE en Google Calendar =====
      final delUri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/$id/events/$eventId',
      );
      final delResp = await http.delete(
        delUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      // 204 No Content es éxito; algunos proxies devuelven 200
      if (delResp.statusCode != 204 &&
          delResp.statusCode != 200 &&
          delResp.statusCode != 410) {
        print(
          'Google Calendar DELETE response: ${delResp.statusCode} ${delResp.body}',
        ); // debug
        throw Exception(
          'Error al eliminar en Google Calendar (HTTP ${delResp.statusCode}): ${delResp.body}',
        );
      }

      // ===== Paso 3: sincronizar lista local =====
      events.removeWhere((x) => x.start == e.start && x.summary == e.summary);
      Get.snackbar(
        'Evento eliminado',
        'El evento "${e.summary}" se eliminó de Google Calendar y de la lista local.',
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
