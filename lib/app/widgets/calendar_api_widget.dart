import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agenda_citas/app/data/models/evento.dart';
import 'package:agenda_citas/app/services/google_auth_service.dart';
import 'package:http/http.dart' as http;

class GoogleCalendarApiWidget extends StatefulWidget {
  final double? height;
  final String? calendarId;

  const GoogleCalendarApiWidget({super.key, this.height, this.calendarId});

  @override
  State<GoogleCalendarApiWidget> createState() =>
      _GoogleCalendarApiWidgetState();
}

class _GoogleCalendarApiWidgetState extends State<GoogleCalendarApiWidget> {
  bool _loading = false;
  String? _error;
  List<Evento> _events = [];

  // Default calendarId (same as used elsewhere). Puedes pasar otro via constructor.
  static const _defaultCalendarId =
      '02fe70469480b93b808fbbbbc7fbcb453059735d42171b343626393437d2314b%40group.calendar.google.com';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await TransparentGoogleAuthService.ensureAuthenticated();
    if (!ok) {
      setState(() {
        _error = 'Usuario no autenticado';
        _loading = false;
      });
      return;
    }

    final headers = TransparentGoogleAuthService.authHeaders;
    if (headers == null) {
      setState(() {
        _error = 'No hay headers de autenticación';
        _loading = false;
      });
      return;
    }

    final calendarId = widget.calendarId ?? _defaultCalendarId;
    try {
      final now = DateTime.now().toUtc();
      final timeMin = now.toIso8601String();
      final timeMax = now
          .add(const Duration(days: 60))
          .toUtc()
          .toIso8601String();

      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/$calendarId/events',
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
        setState(() {
          _error = 'Error al obtener eventos: ${resp.statusCode}';
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? [];

      final parsed = <Evento>[];
      for (final it in items.cast<Map<String, dynamic>>()) {
        final startObj = it['start'] as Map<String, dynamic>?;
        final endObj = it['end'] as Map<String, dynamic>?;
        DateTime? parseDate(dynamic v) {
          if (v == null) return null;
          if (v is String) return DateTime.tryParse(v);
          if (v is Map<String, dynamic>) {
            // Google API: { 'dateTime': '...', 'timeZone': '...'} or { 'date': 'YYYY-MM-DD' }
            if (v['dateTime'] != null) return DateTime.tryParse(v['dateTime']);
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

      setState(() {
        _events = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height ?? 400.0;
    if (_loading) {
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadEvents,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('No hay eventos en el rango seleccionado.')),
      );
    }

    final df = DateFormat('yyyy-MM-dd HH:mm');

    return SizedBox(
      height: height,
      child: RefreshIndicator(
        onRefresh: () async => _loadEvents(),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _events.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = _events[i];
            final start = e.start.toLocal();
            final end = e.end?.toLocal();
            final when = end != null
                ? '${df.format(start)} - ${df.format(end)}'
                : df.format(start);
            return ListTile(
              leading: const Icon(Icons.event),
              title: Text(e.summary),
              subtitle: Text(
                '$when${e.location != null ? '\n${e.location}' : ''}',
              ),
            );
          },
        ),
      ),
    );
  }
}
