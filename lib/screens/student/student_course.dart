import 'package:flutter/material.dart';
import '../../models/attendance_record_model.dart';
import '../../models/course_model.dart';
import '../../services/firestore_service.dart';

/// Shows the student's real, cumulative attendance for this course —
/// every class day held so far, whether they were present or absent
/// each time, and their overall percentage. Pulled straight from the
/// same attendance records the teacher's generated sheet uses, so it's
/// always up to date with real data.
class StudentCourseStatusScreen extends StatelessWidget {
  final CourseModel course;
  final String studentId;

  const StudentCourseStatusScreen({
    super.key,
    required this.course,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: Text(course.courseName)),
      body: FutureBuilder<List<AttendanceRecordModel>>(
        future: firestoreService.attendanceRecordsForCourse(course.courseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final records = [...snapshot.data ?? []]
            ..sort((a, b) => a.date.compareTo(b.date));

          if (records.isEmpty) {
            return const Center(
              child: Text('No attendance has been taken for this course yet.'),
            );
          }

          final totalClasses = records.length;
          final presentCount =
              records.where((r) => r.isPresent(studentId)).length;
          final percentage = (presentCount / totalClasses) * 100;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: percentage >= 75 ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Present $presentCount of $totalClasses classes',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final present = record.isPresent(studentId);
                    return ListTile(
                      leading: Icon(
                        present ? Icons.check_circle : Icons.cancel,
                        color: present ? Colors.green : Colors.red,
                      ),
                      title: Text(record.date),
                      trailing: Text(present ? 'Present' : 'Absent'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}