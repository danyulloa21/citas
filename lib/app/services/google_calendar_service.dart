// lib/app/services/google_calendar_service.dart
import 'dart:convert';
import 'package:agenda_citas/app/modules/configuracion/controllers/configuracion_controller.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  static Future<List<Map<String, dynamic>>> listCalendars() async {
    final token = Get.find<ConfiguracionController>().googleAccessToken;
    if (token == null) {
      throw Exception('No hay providerToken en la sesión (Google).');
    }

    final uri = Uri.parse(
      'https://www.googleapis.com/calendar/v3/users/me/calendarList',
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception(
        'Error al listar calendarios: ${res.statusCode} ${res.body}',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? const [];
    return items.cast<Map<String, dynamic>>();
  }
}
