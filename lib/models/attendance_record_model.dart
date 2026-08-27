class AttendanceRecordModel {
  final String attendanceId;
  final String courseId;
  final String date; // YYYY-MM-DD
  final List<String> presentStudentIds;

  AttendanceRecordModel({
    required this.attendanceId,
    required this.courseId,
    required this.date,
    required this.presentStudentIds,
  });

  factory AttendanceRecordModel.fromMap(
      String attendanceId, Map<String, dynamic> map) {
    return AttendanceRecordModel(
      attendanceId: attendanceId,
      courseId: map['courseId'] ?? '',
      date: map['date'] ?? '',
      presentStudentIds: List<String>.from(map['presentStudentIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'date': date,
      'presentStudentIds': presentStudentIds,
    };
  }

  bool isPresent(String studentUid) => presentStudentIds.contains(studentUid);
}
