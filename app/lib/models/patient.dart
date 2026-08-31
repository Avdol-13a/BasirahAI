class Patient {
  final String id;
  final String name;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? cnic;
  final String? phone;
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.name,
    this.dateOfBirth,
    this.gender,
    this.cnic,
    this.phone,
    required this.createdAt,
  });

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as String,
      name: map['name'] as String,
      dateOfBirth: map['date_of_birth'] != null ? DateTime.tryParse(map['date_of_birth']) : null,
      gender: map['gender'] as String?,
      cnic: map['cnic'] as String?,
      phone: map['phone'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
