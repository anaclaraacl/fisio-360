class AppointmentSummary {
  const AppointmentSummary({
    required this.id,
    required this.patientId,
    required this.startsAt,
    required this.patientName,
    required this.status,
    required this.notes,
  });

  factory AppointmentSummary.fromApi(Map<String, dynamic> json) {
    final startsAt = DateTime.parse(json['startsAt'] as String).toLocal();
    return AppointmentSummary(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      startsAt: startsAt,
      patientName: json['patientName'] as String? ?? 'Paciente',
      status: json['status'] as String? ?? 'scheduled',
      notes: json['notes'] as String? ?? '',
    );
  }

  final String id;
  final String patientId;
  final DateTime startsAt;
  final String patientName;
  final String status;
  final String notes;

  String get time =>
      '${startsAt.day.toString().padLeft(2, '0')}/${startsAt.month.toString().padLeft(2, '0')} ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';

  String get statusLabel => switch (status) {
        'completed' => 'Concluído',
        'cancelled' => 'Cancelado',
        _ => 'Agendado',
      };

  String get kind => notes.isEmpty ? statusLabel : '$statusLabel · $notes';
}
