class Evento {
  final DateTime start;
  final DateTime? end;
  final String summary;
  final String? description;
  final String? location;

  Evento({
    required this.start,
    this.end,
    required this.summary,
    this.description,
    this.location,
  });
}
