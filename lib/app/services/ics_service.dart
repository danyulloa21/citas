import 'package:agenda_citas/app/data/models/evento.dart';
import 'package:http/http.dart' as http;

/// Servicio mínimo para descargar y parsear un archivo .ics (iCal).
class IcsService {
  /// Descarga y parsea eventos de la URL .ics.
  static Future<List<Evento>> fetchEvents(String icsUrl) async {
    final uri = Uri.parse(icsUrl);
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('No se pudo descargar ICS: ${resp.statusCode}');
    }

    final body = resp.body;
    // Manejar folded lines: líneas que comienzan con espacio/tab son continuación
    final unfolded = _unfoldLines(body);
    final lines = unfolded.split(RegExp(r'\r?\n'));

    final events = <Evento>[];
    bool inEvent = false;
    final Map<String, String> current = {};

    for (var raw in lines) {
      final line = raw.trimRight();
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        current.clear();
      } else if (line == 'END:VEVENT') {
        inEvent = false;
        try {
          final dtstartRaw = current.entries
              .firstWhere(
                (e) => e.key.startsWith('DTSTART'),
                orElse: () => MapEntry('', ''),
              )
              .value;
          if (dtstartRaw.isEmpty) continue;
          final start = _parseIcsDate(dtstartRaw);
          DateTime? end;
          final dtendRaw = current.entries
              .firstWhere(
                (e) => e.key.startsWith('DTEND'),
                orElse: () => MapEntry('', ''),
              )
              .value;
          if (dtendRaw.isNotEmpty) {
            end = _parseIcsDate(dtendRaw);
          }

          final summary = current['SUMMARY'] ?? 'Sin título';
          final description = current['DESCRIPTION'];
          final location = current['LOCATION'];

          events.add(
            Evento(
              start: start,
              end: end,
              summary: summary,
              description: description,
              location: location,
            ),
          );
        } catch (_) {
          // ignorar eventos problemáticos
        }
      } else if (inEvent) {
        final sepIndex = line.indexOf(':');
        if (sepIndex > 0) {
          final keyPart = line.substring(0, sepIndex);
          final value = line.substring(sepIndex + 1);
          final key = keyPart.split(';').first;
          current[key] = (current[key] ?? '') + value;
        }
      }
    }

    return events;
  }

  // Unfold folded lines per RFC5545: lines starting with space or tab are continuations
  static String _unfoldLines(String s) {
    final lines = s.split(RegExp(r'\r?\n'));
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0 && (line.startsWith(' ') || line.startsWith('\t'))) {
        buffer.write(line.substring(1));
      } else {
        if (i > 0) buffer.write('\n');
        buffer.write(line);
      }
    }
    return buffer.toString();
  }

  // Parse minimal ICS date formats: handles YYYYMMDDTHHMMSSZ, YYYYMMDDTHHMMSS, and YYYYMMDD
  static DateTime _parseIcsDate(String raw) {
    // raw might include timezone params, but here we expect only the value
    final s = raw.replaceAll('\\', '');
    // Some lines might be like DTSTART;TZID=America/Santiago:20251002T080000
    final parts = s.split(':');
    final value = parts.length > 1 ? parts.sublist(1).join(':') : parts.first;

    if (RegExp(r"^\d{8}T\d{6}Z$").hasMatch(value)) {
      return DateTime.parse(value).toUtc();
    }
    if (RegExp(r"^\d{8}T\d{6}$").hasMatch(value)) {
      // treat as local
      final dt = DateTime.parse(
        value.replaceFirstMapped(
          RegExp(r"^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})$"),
          (m) => '${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}',
        ),
      );
      return dt;
    }
    if (RegExp(r"^\d{8}$").hasMatch(value)) {
      final dt = DateTime.parse(
        value.replaceFirstMapped(
          RegExp(r"^(\d{4})(\d{2})(\d{2})$"),
          (m) => '${m[1]}-${m[2]}-${m[3]}',
        ),
      );
      return dt;
    }

    // Fallback: try DateTime.parse
    return DateTime.parse(value);
  }
}
