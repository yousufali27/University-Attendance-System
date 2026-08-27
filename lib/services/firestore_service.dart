import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/attendance_record_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- Courses ----------

  /// Joins a course by its exact course ID (e.g. "CSE101"). Since the
  /// course ID is also the Firestore document ID, this is a direct
  /// lookup — the course shows up immediately once found.
  Future<String> joinCourseById({
    required String studentId,
    required String courseId,
  }) async {
    final doc = await _db.collection('courses').doc(courseId.trim()).get();
    if (!doc.exists) {
      throw StateError('No course found with ID "$courseId"');
    }

    await doc.reference.update({
      'studentIds': FieldValue.arrayUnion([studentId]),
    });
    return (doc.data()?['courseName'] ?? '') as String;
  }

  /// Creates a course and auto-generates its course ID from the course
  /// name's first 3 letters plus a running number for that code, e.g.
  /// "Math" -> "MAT101", the next course starting with "Mat..." ->
  /// "MAT102". No dept in the ID anymore — just like real course codes
  /// (MAT205, CSE101, etc).
  /// Returns the generated course ID.
  Future<String> addCourse({
    required String teacherId,
    required String courseName,
    required String dept,
    required String credit,
  }) async {
    final nameLetters =
        courseName.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final nameCode =
        nameLetters.length >= 3 ? nameLetters.substring(0, 3) : nameLetters;

    // Count existing course IDs that start with this 3-letter code (a
    // document-ID range query) so the next course gets the next number.
    final existing = await _db
        .collection('courses')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: nameCode)
        .where(FieldPath.documentId, isLessThan: '$nameCode\uf8ff')
        .get();
    final courseId = '$nameCode${101 + existing.docs.length}';

    await _db.collection('courses').doc(courseId).set({
      'courseName': courseName,
      'dept': dept.trim(),
      'credit': credit.trim(),
      'teacherId': teacherId,
      'studentIds': <String>[],
      'studentNames': <String, String>{},
      'isEnded': false,
    });
    return courseId;
  }

  /// Manually adds a student's registration number (and name) to a
  /// course's roster. Safe to call more than once for the same student
  /// (arrayUnion dedupes the id; the name is simply overwritten).
  Future<void> addStudentToCourse({
    required String courseId,
    required String studentId,
    required String studentName,
  }) async {
    await _db.collection('courses').doc(courseId).update({
      'studentIds': FieldValue.arrayUnion([studentId]),
      'studentNames.$studentId': studentName,
    });
  }

  /// Registration number -> name for every student who has registered
  /// through the app. Used when generating the attendance sheet so names
  /// show up next to registration numbers even for students the teacher
  /// never manually added.
  Future<Map<String, String>> studentNamesByRegistrationNumber() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();

    final result = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final regNo = (data['registrationNumber'] ?? '').toString().trim();
      final name = (data['name'] ?? '').toString().trim();
      if (regNo.isNotEmpty && name.isNotEmpty) {
        result[regNo] = name;
      }
    }
    return result;
  }

  /// Marks a course as ended. Once ended, attendance should no longer be
  /// taken for it; the teacher generates the attendance sheet instead.
  Future<void> endCourse(String courseId) async {
    await _db.collection('courses').doc(courseId).update({
      'isEnded': true,
    });
  }

  /// All attendance records ever taken for a course (one per class day).
  /// Filters by courseId only (no orderBy), so it needs no Firestore
  /// composite index — the caller sorts by actual date since the stored
  /// 'date' string is dd-MM-yyyy and doesn't sort correctly as text.
  Future<List<AttendanceRecordModel>> attendanceRecordsForCourse(
    String courseId,
  ) async {
    final snap = await _db
        .collection('attendance')
        .where('courseId', isEqualTo: courseId)
        .get();
    return snap.docs
        .map((d) => AttendanceRecordModel.fromMap(d.id, d.data()))
        .toList();
  }

  /// Courses taught by this teacher.
  Stream<List<CourseModel>> coursesForTeacher(String teacherId) {
    return _db
        .collection('courses')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CourseModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<CourseModel> getCourse(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('Course $courseId not found');
    }
    return CourseModel.fromMap(doc.id, doc.data()!);
  }

  // ---------- Attendance: Teacher side ----------

  /// Writes today's attendance for a course. Called when the teacher
  /// taps "Done" on the roster screen. Overwrites any existing record
  /// for the same course+date (docId is deterministic), so resubmitting
  /// the same day just updates it.
  Future<void> submitAttendance({
    required String courseId,
    required String date, // YYYY-MM-DD
    required List<String> presentStudentIds,
  }) async {
    final docId = '${courseId}_$date';
    await _db.collection('attendance').doc(docId).set({
      'courseId': courseId,
      'date': date,
      'presentStudentIds': presentStudentIds,
    });
  }

  // ---------- Attendance: Student side ----------

  /// Real-time stream of today's attendance docs, used by the
  /// student dashboard to show present/absent badges per course.
  Stream<List<AttendanceRecordModel>> attendanceForDate(String date) {
    return _db
        .collection('attendance')
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceRecordModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Courses a student is enrolled in (studentIds array-contains uid).
  Stream<List<CourseModel>> coursesForStudent(String studentId) {
    return _db
        .collection('courses')
        .where('studentIds', arrayContains: studentId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CourseModel.fromMap(d.id, d.data()))
            .toList());
  }
}