class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'teacher' or 'student'

  /// Student registration number, entered at sign-up. Empty for teachers
  /// (and for any student account created before this field existed).
  final String registrationNumber;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.registrationNumber = '',
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      registrationNumber: map['registrationNumber'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'registrationNumber': registrationNumber,
    };
  }

  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
}
