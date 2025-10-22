// lib/app/services/google_calendar_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleCalendarService {
  // ⭐️ Obtiene el access token (el de Google) desde la sesión de Supabase
  static String? get accessToken =>
      Supabase.instance.client.auth.currentSession?.providerToken;

  // ⭐️ Lista los calendarios del usuario
  static Future<List<Map<String, dynamic>>> listCalendars() async {
    final token = accessToken;
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
