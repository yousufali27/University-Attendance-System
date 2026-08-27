class CourseModel {
  final String courseId;
  final String courseName;
  final String dept;
  final String credit;
  final String teacherId;
  final List<String> studentIds;

  /// Registration number -> student name, for students the teacher added
  /// manually by hand (via "Add Student"). Students who registered
  /// themselves through the app already have their name in the `users`
  /// collection, so they don't need an entry here.
  final Map<String, String> studentNames;

  /// True once the teacher has ended the course. Ended courses no longer
  /// take attendance; the teacher generates the attendance sheet instead.
  final bool isEnded;

  CourseModel({
    required this.courseId,
    required this.courseName,
    required this.teacherId,
    required this.studentIds,
    this.dept = '',
    this.credit = '',
    this.studentNames = const {},
    this.isEnded = false,
  });

  factory CourseModel.fromMap(String courseId, Map<String, dynamic> map) {
    return CourseModel(
      courseId: courseId,
      courseName: map['courseName'] ?? '',
      dept: map['dept'] ?? '',
      credit: map['credit'] ?? '',
      teacherId: map['teacherId'] ?? '',
      studentIds: List<String>.from(map['studentIds'] ?? []),
      studentNames: Map<String, String>.from(map['studentNames'] ?? {}),
      // Defaults to false so existing course docs without this field
      // (created before this feature) keep working with no migration.
      isEnded: map['isEnded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseName': courseName,
      'dept': dept,
      'credit': credit,
      'teacherId': teacherId,
      'studentIds': studentIds,
      'studentNames': studentNames,
      'isEnded': isEnded,
    };
  }
}
