class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.condition,
    required this.birthDate,
    required this.age,
    this.colorValue = 0xFFCFE5FF,
  });

  factory Patient.fromApi(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sem nome',
      phone: json['phone'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      birthDate: json['birthDate'] as String? ?? '',
      age: json['age'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String phone;
  final String condition;
  final String birthDate;
  final int age;
  final int colorValue;

  String get subtitle => condition;
}
